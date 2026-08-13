import 'dart:async';
import 'dart:typed_data';

import '../locker/locker_service.dart';
import '../managers/ble_connection_manager.dart';
import '../managers/timeout_manager.dart';
import '../models/ble_device.dart';
import '../models/unlock_payload.dart';
import '../protocol/packet_builder.dart';
import '../protocol/packet_parser.dart';
import '../protocol/parsed_ble_response.dart';
import '../protocol/real_packet_builder.dart';
import '../transport/ble_log.dart';
import '../transport/flutter_blue_transport.dart';
import 'ble_unlock_engine.dart';

/// Orchestrates unlock → optional backend confirm.
///
/// Real hardware delegates to [BleUnlockEngine] (production Collect path).
/// Virtual MCU / mock keeps Phase-10 via [PacketBuilder] + [LockerService].
///
/// Production Collect (Phase 17) calls [BleUnlockEngine] directly; this class
/// remains for Virtual MCU / legacy callers and shares the same engine.
class UnlockService {
  UnlockService({
    required LockerService locker,
    BleUnlockEngine? engine,
    PacketBuilder? packetBuilder,
    RealPacketBuilder? realPacketBuilder,
    PacketParser? packetParser,
    TimeoutManager? timeouts,
    Future<bool> Function(UnlockPacketRequest request, UnlockResult result)?
        confirmWithBackend,
  })  : _locker = locker,
        _engine = engine ??
            BleUnlockEngine(
              locker: locker,
              packetBuilder: realPacketBuilder,
              packetParser: packetParser,
              timeouts: timeouts,
            ),
        _builder = packetBuilder ?? PacketBuilder(),
        _realBuilder = realPacketBuilder ?? const RealPacketBuilder(),
        _parser = packetParser ?? PacketParser(),
        _confirmWithBackend = confirmWithBackend;

  final LockerService _locker;
  final BleUnlockEngine _engine;
  final PacketBuilder _builder;
  final RealPacketBuilder _realBuilder;
  final PacketParser _parser;
  final Future<bool> Function(UnlockPacketRequest request, UnlockResult result)?
      _confirmWithBackend;

  BleUnlockEngine get engine => _engine;

  BleConnectionManager get connection => _engine.connection;

  PacketBuilder get packetBuilder => _builder;
  RealPacketBuilder get realPacketBuilder => _realBuilder;
  PacketParser get packetParser => _parser;

  /// Full unlock flow for Collect — consumes backend [UnlockPayload] only.
  /// Kept for JWT-era callers; Phase 17 Collect does not use this.
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

  /// Packet-level unlock. Real BLE → [BleUnlockEngine.unlockOpen].
  Future<UnlockResult> unlock(UnlockPacketRequest request) async {
    BleLog.d(
      'UnlockService.start order=${request.orderId} '
      'locker=${request.lockerId} box=${request.boxId} '
      'port=${request.port} terminal=${request.terminalNumber} '
      'tx=${request.transactionId} real=${_locker.config.isRealBle}',
    );

    if (_locker.config.isRealBle) {
      return _unlockRealFirmware(request);
    }

    if (request.collectionToken.isEmpty) {
      return UnlockResult.fail(
        stage: 'payload',
        message: 'Missing unlockToken from backend UnlockPayload',
      );
    }
    return _unlockPhase10(request);
  }

  // ── Real CC2340 firmware: shared BleUnlockEngine (Demo-proven) ──────

  Future<UnlockResult> _unlockRealFirmware(UnlockPacketRequest request) async {
    var result = await _engine.unlockOpen(request);

    if (!result.success) {
      return result;
    }

    BleLog.d('UnlockService stage=backend_confirm');
    var confirmed = false;
    try {
      final confirm = _confirmWithBackend;
      if (confirm != null) {
        confirmed = await confirm(request, result);
      } else {
        BleLog.d('Backend confirm skipped — caller handles collect-complete');
      }
    } catch (e) {
      BleLog.e('Backend confirm failed (non-fatal)', e);
    }

    return UnlockResult.ok(
      stage: 'complete',
      message: result.message ?? 'Locker Opened Successfully',
      deviceId: result.deviceId,
      deviceName: result.deviceName,
      mtu: result.mtu,
      openResponse: result.openResponse,
      backendConfirmed: confirmed,
    );
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
            'Backend confirm skipped — caller handles collect-complete',
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

  /// Write builder bytes and wait/parse one notification (via shared engine).
  Future<ParsedBleResponse> writeAndWait({
    required Uint8List packet,
    Duration? timeout,
  }) {
    return _engine.writeAndWait(packet: packet, timeout: timeout);
  }

  Future<void> _safeDisconnect() => _engine.disconnect();
}
