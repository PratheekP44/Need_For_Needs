import 'dart:async';
import 'dart:typed_data';

import '../locker/locker_service.dart';
import '../managers/ble_connection_manager.dart';
import '../managers/timeout_manager.dart';
import '../models/ble_device.dart';
import '../models/unlock_payload.dart';
import '../protocol/packet_builder.dart';
import '../protocol/packet_parser.dart';
import '../protocol/packet_types.dart';
import '../protocol/parsed_ble_response.dart';
import '../protocol/real_packet_builder.dart';
import '../transport/ble_log.dart';
import '../transport/flutter_blue_transport.dart';

/// Orchestrates Collect → BLE unlock → parse → optional backend confirm.
///
/// Real hardware uses [RealPacketBuilder] (fixed 32-byte firmware packet).
/// Virtual MCU / mock keeps Phase-10 via [PacketBuilder] + [LockerService].
class UnlockService {
  UnlockService({
    required LockerService locker,
    PacketBuilder? packetBuilder,
    RealPacketBuilder? realPacketBuilder,
    PacketParser? packetParser,
    TimeoutManager? timeouts,
    Future<bool> Function(UnlockPacketRequest request, UnlockResult result)?
        confirmWithBackend,
  })  : _locker = locker,
        _builder = packetBuilder ?? PacketBuilder(),
        _realBuilder = realPacketBuilder ?? const RealPacketBuilder(),
        _parser = packetParser ?? PacketParser(),
        _timeouts = timeouts ?? const TimeoutManager(),
        _confirmWithBackend = confirmWithBackend;

  final LockerService _locker;
  final PacketBuilder _builder;
  final RealPacketBuilder _realBuilder;
  final PacketParser _parser;
  final TimeoutManager _timeouts;
  final Future<bool> Function(UnlockPacketRequest request, UnlockResult result)?
      _confirmWithBackend;

  BleConnectionManager get connection => BleConnectionManager(
        connection: _locker.connectionManager,
        config: _locker.config,
      );

  PacketBuilder get packetBuilder => _builder;
  RealPacketBuilder get realPacketBuilder => _realBuilder;
  PacketParser get packetParser => _parser;

  /// Full unlock flow for Collect — consumes backend [UnlockPayload] only.
  Future<UnlockResult> unlockWithPayload(UnlockPayload payload) async {
    BleLog.d(
      'Unlock request jti=${payload.jti} order=${payload.orderId} '
      'locker=${payload.lockerId} port=${payload.port} '
      'real=${_locker.config.isRealBle}',
    );
    try {
      payload.validateForUnlock();
    } catch (e) {
      return UnlockResult.fail(
        stage: 'payload',
        message: e.toString(),
        error: e,
      );
    }
    return unlock(payload.toUnlockPacketRequest());
  }

  /// Packet-level unlock (tests / internal). Prefer [unlockWithPayload].
  Future<UnlockResult> unlock(UnlockPacketRequest request) async {
    BleLog.d(
      'UnlockService.start order=${request.orderId} '
      'locker=${request.lockerId} box=${request.boxId} '
      'port=${request.port} terminal=${request.terminalNumber} '
      'tx=${request.transactionId} real=${_locker.config.isRealBle}',
    );

    if (request.collectionToken.isEmpty) {
      return UnlockResult.fail(
        stage: 'payload',
        message: 'Missing unlockToken from backend UnlockPayload',
      );
    }

    if (_locker.config.isRealBle) {
      return _unlockRealFirmware(request);
    }
    return _unlockPhase10(request);
  }

  // ── Real CC2340 firmware: fixed 32-byte packet ─────────────────────

  Future<UnlockResult> _unlockRealFirmware(UnlockPacketRequest request) async {
    final ble = connection;
    ParsedBleResponse? openParsed;

    try {
      await ble.ensurePermissions();

      BleLog.d('UnlockService stage=scan (real firmware)');
      final List<BleDevice> devices;
      try {
        devices = await ble.scan().timeout(
          _locker.config.scanTimeout + const Duration(seconds: 5),
          onTimeout: () {
            BleLog.e('Timeout — scan');
            throw TimeoutException('Device scan timed out');
          },
        );
      } on TimeoutException catch (e) {
        return UnlockResult.fail(
          stage: 'scan',
          message: 'Device not found (scan timeout)',
          error: e,
        );
      }

      var device = ble.findByAddress(devices, request.bluetoothAddress);
      device ??= ble.selectLockerDevice(devices);
      if (device == null) {
        return UnlockResult.fail(
          stage: 'scan',
          message: 'Device not found — power on LKRM-V2 and stand nearby',
        );
      }

      BleLog.d('UnlockService stage=connect (real firmware)');
      try {
        await _locker.connect(device, lockerId: request.lockerId).timeout(
          _locker.config.connectTimeout + const Duration(seconds: 20),
          onTimeout: () {
            BleLog.e('Timeout — connect');
            throw TimeoutException('Connection timeout');
          },
        );
        BleLog.d('Connected');
        final t = _locker.transport;
        if (t is FlutterBlueTransport) {
          BleLog.d('MTU ${t.lastMtu}');
          BleLog.d('Services ${t.discoveredServices.length}');
        }
      } on TimeoutException catch (e) {
        await _safeDisconnect();
        return UnlockResult.fail(
          stage: 'connect',
          message: 'Connection timeout',
          error: e,
        );
      } catch (e) {
        await _safeDisconnect();
        return UnlockResult.fail(
          stage: 'connect',
          message: 'Connection failed: $e',
          error: e,
        );
      }

      final mtu = switch (_locker.transport) {
        final FlutterBlueTransport fbp => fbp.lastMtu,
        _ => _locker.config.desiredMtu,
      };

      // Single OPEN write — no Phase-10 AUTH / JSON.
      BleLog.d('UnlockService stage=open (real 32-byte firmware packet)');
      final packet = _realBuilder.buildOpen(request);
      if (packet.length != RealPacketBuilder.packetLength) {
        await _safeDisconnect();
        return UnlockResult.fail(
          stage: 'payload',
          message:
              'Firmware packet must be ${RealPacketBuilder.packetLength} bytes, '
              'got ${packet.length}',
        );
      }

      try {
        final raw = await writeAndWait(
          packet: packet,
          timeout: _timeouts.responseTimeout(BlePacketType.openBox),
        );
        openParsed = raw;
        BleLog.d('Decoded Response: $openParsed');

        final success = openParsed.kind == BleResponseKind.unlockSuccess ||
            openParsed.kind == BleResponseKind.ack ||
            openParsed.opened == true ||
            // Firmware may return a short/unknown status; treat non-NACK as OK
            // once a notify arrives after a valid 32-byte OPEN write.
            (openParsed.kind != BleResponseKind.nack &&
                openParsed.kind != BleResponseKind.unlockFailure &&
                openParsed.kind != BleResponseKind.error &&
                openParsed.kind != BleResponseKind.authRejected);

        if (!success) {
          await _safeDisconnect();
          return UnlockResult.fail(
            stage: 'open',
            message: openParsed.message ?? 'Unlock Failure',
            openResponse: openParsed,
          );
        }
      } on TimeoutException catch (e) {
        await _safeDisconnect();
        return UnlockResult.fail(
          stage: 'open_timeout',
          message: 'Notification timeout (OPEN)',
          error: e,
          openResponse: openParsed,
        );
      } catch (e) {
        await _safeDisconnect();
        return UnlockResult.fail(
          stage: 'open',
          message: 'Unlock write/notify failed: $e',
          error: e,
          openResponse: openParsed,
        );
      }

      var result = UnlockResult.ok(
        stage: 'unlocked',
        message: 'Locker Opened Successfully',
        deviceId: device.id,
        deviceName: device.name,
        mtu: mtu,
        openResponse: openParsed,
      );

      BleLog.d('UnlockService stage=backend_confirm');
      var confirmed = false;
      try {
        final confirm = _confirmWithBackend;
        if (confirm != null) {
          confirmed = await confirm(request, result);
        } else {
          BleLog.d(
            'Backend confirm skipped — no collect-complete endpoint',
          );
        }
      } catch (e) {
        BleLog.e('Backend confirm failed (non-fatal)', e);
      }

      result = UnlockResult.ok(
        stage: 'complete',
        message: 'Locker Opened Successfully',
        deviceId: device.id,
        deviceName: device.name,
        mtu: mtu,
        openResponse: openParsed,
        backendConfirmed: confirmed,
      );

      await _safeDisconnect();
      BleLog.d('UnlockService done success=true (real firmware)');
      return result;
    } catch (e, st) {
      BleLog.e('UnlockService unexpected error (real)', e);
      BleLog.d('$st');
      await _safeDisconnect();
      return UnlockResult.fail(
        stage: 'unexpected',
        message: e.toString(),
        error: e,
        openResponse: openParsed,
      );
    }
  }

  // ── Virtual MCU / mock: existing Phase-10 path ─────────────────────

  Future<UnlockResult> _unlockPhase10(UnlockPacketRequest request) async {
    final ble = connection;
    ParsedBleResponse? authParsed;
    ParsedBleResponse? openParsed;

    try {
      await ble.ensurePermissions();

      BleLog.d('UnlockService stage=scan');
      final List<BleDevice> devices;
      try {
        devices = await ble.scan().timeout(
          _locker.config.scanTimeout + const Duration(seconds: 5),
          onTimeout: () {
            BleLog.e('Timeout — scan');
            throw TimeoutException('Device scan timed out');
          },
        );
      } on TimeoutException catch (e) {
        return UnlockResult.fail(
          stage: 'scan',
          message: 'Device not found (scan timeout)',
          error: e,
        );
      }

      var device = ble.findByAddress(devices, request.bluetoothAddress);
      device ??= ble.selectLockerDevice(devices);
      if (device == null) {
        return UnlockResult.fail(
          stage: 'scan',
          message: 'Device not found — power on LKRM-V2 and stand nearby',
        );
      }

      BleLog.d('UnlockService stage=connect');
      try {
        await _locker.connect(device, lockerId: request.lockerId).timeout(
          _locker.config.connectTimeout + const Duration(seconds: 20),
          onTimeout: () {
            BleLog.e('Timeout — connect');
            throw TimeoutException('Connection timeout');
          },
        );
        BleLog.d('Connected');
      } on TimeoutException catch (e) {
        await _safeDisconnect();
        return UnlockResult.fail(
          stage: 'connect',
          message: 'Connection timeout',
          error: e,
        );
      } catch (e) {
        await _safeDisconnect();
        return UnlockResult.fail(
          stage: 'connect',
          message: 'Connection failed: $e',
          error: e,
        );
      }

      final mtu = switch (_locker.transport) {
        final FlutterBlueTransport fbp => fbp.lastMtu,
        _ => _locker.config.desiredMtu,
      };

      BleLog.d('UnlockService stage=auth');
      final previewAuth = _builder.buildAuth(request);
      BleLog.d('AUTH preview length=${previewAuth.length}');

      try {
        final authResult = await _locker.authenticateCollection(
          orderId: request.orderId,
          lockerId: request.lockerId,
          boxId: request.effectivePortId,
          collectionToken: request.collectionToken,
          port: request.port,
        );
        if (authResult.response != null) {
          authParsed = _parser.parsePacket(authResult.response!);
          BleLog.d('Decoded Response: $authParsed');
        }
        if (!authResult.success) {
          await _safeDisconnect();
          return UnlockResult.fail(
            stage: 'auth',
            message: authResult.message ??
                (authResult.timedOut
                    ? 'Notification timeout (AUTH)'
                    : 'AUTH failed'),
            authResponse: authParsed,
          );
        }
        if (authResult.responsePayload?['accepted'] != true) {
          await _safeDisconnect();
          return UnlockResult.fail(
            stage: 'auth',
            message: 'AUTH NACK / rejected',
            authResponse: authParsed,
          );
        }
      } on FormatException catch (e) {
        await _safeDisconnect();
        return UnlockResult.fail(
          stage: 'auth',
          message: e.message,
          error: e,
          authResponse: authParsed,
        );
      } on TimeoutException catch (e) {
        await _safeDisconnect();
        return UnlockResult.fail(
          stage: 'auth',
          message: 'Notification timeout (AUTH)',
          error: e,
          authResponse: authParsed,
        );
      }

      BleLog.d('UnlockService stage=open');
      final previewOpen = _builder.buildUnlock(request);
      BleLog.d('OPEN_BOX preview length=${previewOpen.length}');

      try {
        final openResult = await _locker.openBox(
          orderId: request.orderId,
          lockerId: request.lockerId,
          boxId: request.effectivePortId,
          collectionToken: request.collectionToken,
          port: request.port,
        );
        if (openResult.response != null) {
          openParsed = _parser.parsePacket(openResult.response!);
          BleLog.d('Decoded Response: $openParsed');
        }
        if (!openResult.success ||
            openResult.responsePayload?['opened'] != true) {
          await _safeDisconnect();
          return UnlockResult.fail(
            stage: openResult.timedOut ? 'open_timeout' : 'open',
            message: openResult.timedOut
                ? 'Notification timeout (OPEN)'
                : (openResult.message ?? 'Unlock Failure'),
            authResponse: authParsed,
            openResponse: openParsed,
          );
        }
      } on TimeoutException catch (e) {
        await _safeDisconnect();
        return UnlockResult.fail(
          stage: 'open',
          message: 'Notification timeout (OPEN)',
          error: e,
          authResponse: authParsed,
          openResponse: openParsed,
        );
      }

      var result = UnlockResult.ok(
        stage: 'unlocked',
        message: 'Locker Opened Successfully',
        deviceId: device.id,
        deviceName: device.name,
        mtu: mtu,
        authResponse: authParsed,
        openResponse: openParsed,
      );

      BleLog.d('UnlockService stage=backend_confirm');
      var confirmed = false;
      try {
        final confirm = _confirmWithBackend;
        if (confirm != null) {
          confirmed = await confirm(request, result);
        } else {
          BleLog.d(
            'Backend confirm skipped — no collect-complete endpoint',
          );
        }
      } catch (e) {
        BleLog.e('Backend confirm failed (non-fatal)', e);
      }

      result = UnlockResult.ok(
        stage: 'complete',
        message: 'Locker Opened Successfully',
        deviceId: device.id,
        deviceName: device.name,
        mtu: mtu,
        authResponse: authParsed,
        openResponse: openParsed,
        backendConfirmed: confirmed,
      );

      await _safeDisconnect();
      BleLog.d('UnlockService done success=true backendConfirmed=$confirmed');
      return result;
    } catch (e, st) {
      BleLog.e('UnlockService unexpected error', e);
      BleLog.d('$st');
      await _safeDisconnect();
      return UnlockResult.fail(
        stage: 'unexpected',
        message: e.toString(),
        error: e,
        authResponse: authParsed,
        openResponse: openParsed,
      );
    }
  }

  /// Write builder bytes and wait/parse one notification.
  Future<ParsedBleResponse> writeAndWait({
    required Uint8List packet,
    Duration? timeout,
  }) async {
    final ble = connection;
    await ble.writePacket(packet);
    final raw = await ble.waitForNotification(
      timeout: timeout ?? _timeouts.responseTimeout(BlePacketType.openBox),
    );
    return _parser.parse(raw);
  }

  Future<void> _safeDisconnect() async {
    try {
      await _locker.disconnectSafely();
    } catch (e) {
      BleLog.d('Disconnect error (ignored): $e');
      try {
        await connection.disconnect();
      } catch (_) {}
    }
  }
}
