import 'dart:async';
import 'dart:typed_data';

import '../locker/locker_service.dart';
import '../managers/ble_connection_manager.dart';
import '../managers/timeout_manager.dart';
import '../models/ble_device.dart';
import '../protocol/packet_parser.dart';
import '../protocol/packet_types.dart';
import '../protocol/parsed_ble_response.dart';
import '../protocol/real_packet_builder.dart';
import '../transport/ble_log.dart';
import '../transport/flutter_blue_transport.dart';

/// Result of the proven Demo connect pipeline (scan → connect → MTU → GATT → notify).
class BleUnlockConnectResult {
  const BleUnlockConnectResult({
    required this.device,
    this.mtu,
    this.services = const [],
    this.notifyEnabled = false,
  });

  final BleDevice device;
  final int? mtu;
  final List<GattServiceInfo> services;
  final bool notifyEnabled;
}

/// Shared BLE unlock engine used by production Collect.
///
/// This is the single reference implementation proven on real LKRM-V2 hardware.
/// It reuses [ConnectionManager] / [BleTransport] / [RealPacketBuilder] /
/// [PacketParser] — it does not reimplement them.
class BleUnlockEngine {
  BleUnlockEngine({
    required LockerService locker,
    RealPacketBuilder? packetBuilder,
    PacketParser? packetParser,
    TimeoutManager? timeouts,
  })  : _locker = locker,
        _builder = packetBuilder ?? const RealPacketBuilder(),
        _parser = packetParser ?? PacketParser(),
        _timeouts = timeouts ?? const TimeoutManager();

  final LockerService _locker;
  final RealPacketBuilder _builder;
  final PacketParser _parser;
  final TimeoutManager _timeouts;

  static const String defaultTargetName = 'LKRM-V2';

  LockerService get locker => _locker;

  BleConnectionManager get connection => BleConnectionManager(
        connection: _locker.connectionManager,
        config: _locker.config,
      );

  RealPacketBuilder get packetBuilder => _builder;
  PacketParser get packetParser => _parser;

  bool get isConnected =>
      _locker.transport.isConnected || connection.isConnected;

  FlutterBlueTransport? get _fbp {
    final t = _locker.transport;
    return t is FlutterBlueTransport ? t : null;
  }

  /// Scan nearby lockers (production Collect path).
  Future<List<BleDevice>> scan({Duration? timeout}) async {
    BleLog.d('[BleUnlockEngine] Scan');
    await connection.ensurePermissions();
    final wait = timeout ?? const Duration(seconds: 25);
    return _locker.scanForLockers().timeout(
      wait,
      onTimeout: () {
        throw TimeoutException('Device not found (scan timeout)');
      },
    );
  }

  /// Prefer exact / contains name match (LKRM-V2), then target flag, then RSSI.
  BleDevice? findTarget(
    List<BleDevice> devices, {
    String targetName = defaultTargetName,
  }) {
    final needle = targetName.trim().toLowerCase();
    if (needle.isNotEmpty) {
      for (final d in devices) {
        if (d.name.toLowerCase() == needle) return d;
      }
      for (final d in devices) {
        if (d.name.toLowerCase().contains(needle)) return d;
      }
    }
    final targets = devices.where((d) => d.isTargetLocker).toList();
    final selected = connection.selectLockerDevice(targets);
    if (selected != null) return selected;
    return connection.selectLockerDevice(devices);
  }

  /// Scan → Find device by name → Connect → MTU → Discover → Enable notifications.
  ///
  /// Exact pipeline used by production Collect on real hardware.
  Future<BleUnlockConnectResult> connect({
    String targetDeviceName = defaultTargetName,
    void Function(String stage)? onStage,
  }) async {
    onStage?.call('scan');
    BleLog.d('[BleUnlockEngine] Scan');
    final devices = await scan();

    final targetName = targetDeviceName.trim().isEmpty
        ? defaultTargetName
        : targetDeviceName.trim();
    final device = findTarget(devices, targetName: targetName);
    if (device == null) {
      throw StateError(
        'Device not found — power on $targetName and stand nearby '
        '(scanned ${devices.length} device(s))',
      );
    }
    BleLog.d(
      '[BleUnlockEngine] Find $targetName → ${device.name} (${device.id})',
    );

    onStage?.call('connect');
    BleLog.d('[BleUnlockEngine] Connect');
    try {
      await connection.connect(device).timeout(
        _locker.config.connectTimeout + const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('Unable to connect (timeout)');
        },
      );
    } on TimeoutException {
      await disconnect();
      rethrow;
    } catch (e) {
      await disconnect();
      throw StateError('Unable to connect: $e');
    }

    final fbp = _fbp;
    final mtu = fbp?.lastMtu ?? _locker.currentConnection.mtu;
    final services = fbp?.discoveredServices ?? const <GattServiceInfo>[];
    final notifyOn = fbp?.pipelineNotifyEnabled ??
        fbp?.linkState.notificationsEnabled ??
        true;

    BleLog.d('[BleUnlockEngine] Connected');
    BleLog.d('[BleUnlockEngine] MTU ${mtu ?? _locker.config.desiredMtu}');
    BleLog.d('[BleUnlockEngine] Services ${services.length}');
    for (final s in services) {
      BleLog.d('[BleUnlockEngine]   Service ${s.uuid}');
      for (final c in s.characteristics) {
        BleLog.d(
          '[BleUnlockEngine]   Characteristics ${c.uuid} ${c.properties}',
        );
      }
    }
    BleLog.d(
      '[BleUnlockEngine] Notify enabled ${notifyOn ? 'YES' : '—'}',
    );

    onStage?.call('connected');
    return BleUnlockConnectResult(
      device: device,
      mtu: mtu,
      services: services,
      notifyEnabled: notifyOn,
    );
  }

  /// Build fixed 32-byte firmware packet via [RealPacketBuilder].
  Uint8List buildPacket({
    required int command,
    required UnlockPacketRequest request,
  }) {
    final packet = _builder.build(command: command, request: request);
    assert(packet.length == RealPacketBuilder.packetLength);
    BleLog.d(
      '[BleUnlockEngine] Packet length ${packet.length} HEX=${_hex(packet)}',
    );
    for (var i = 0; i < packet.length; i++) {
      BleLog.d(
        '[BleUnlockEngine] Packet bytes[$i] = '
        '0x${packet[i].toRadixString(16).padLeft(2, '0')} (${packet[i]})',
      );
    }
    return packet;
  }

  /// Write characteristic → wait for notification → parse.
  Future<ParsedBleResponse> writeAndWait({
    required Uint8List packet,
    Duration? timeout,
  }) async {
    if (!isConnected) {
      throw StateError('Write failed — not connected');
    }
    try {
      await connection.writePacket(packet);
      BleLog.d('[BleUnlockEngine] Write success');
    } catch (e) {
      BleLog.e('[BleUnlockEngine] Write failed', e);
      throw StateError('Write failed: $e');
    }

    final wait =
        timeout ?? _timeouts.responseTimeout(BlePacketType.openBox);
    try {
      final raw = await connection.waitForNotification(timeout: wait);
      BleLog.d(
        '[BleUnlockEngine] Notification HEX ${_hex(raw)}',
      );
      return _parser.parse(raw);
    } on TimeoutException catch (e) {
      BleLog.e('[BleUnlockEngine] Notification timeout', e);
      throw TimeoutException('Notification timeout');
    }
  }

  /// Build + write + wait (Demo SEND PACKET / Collect OPEN).
  Future<ParsedBleResponse> sendPacket({
    required int command,
    required UnlockPacketRequest request,
    Duration? timeout,
  }) {
    final packet = buildPacket(command: command, request: request);
    return writeAndWait(packet: packet, timeout: timeout);
  }

  Future<void> disconnect() async {
    BleLog.d('[BleUnlockEngine] Disconnect');
    try {
      await _locker.disconnectSafely();
    } catch (e) {
      BleLog.d('[BleUnlockEngine] Disconnect error (ignored): $e');
      try {
        await connection.disconnect();
      } catch (_) {}
    }
  }

  /// Full production Collect unlock using the Demo-proven pipeline.
  ///
  /// Packet Port / Box / Terminal must already be set from the order
  /// ([CollectUnlockInfo.toUnlockPacketRequest]) — never hardcoded here.
  ///
  /// Connect (by device name) → OPEN 32-byte packet → wait notify → disconnect.
  Future<UnlockResult> unlockOpen(
    UnlockPacketRequest request, {
    String targetDeviceName = defaultTargetName,
    void Function(String stage)? onStage,
  }) async {
    _logUnlockRequest(request);

    ParsedBleResponse? openParsed;
    BleUnlockConnectResult? linked;

    try {
      linked = await connect(
        targetDeviceName: targetDeviceName,
        onStage: onStage,
      );

      onStage?.call('open');
      final packet = buildPacket(
        command: FirmwareCommand.open,
        request: request,
      );
      BleLog.d('[BleUnlockEngine] Packet HEX ${_hex(packet)}');
      openParsed = await writeAndWait(packet: packet);

      BleLog.d(
        '[BleUnlockEngine] Notification HEX=${openParsed.rawHex} '
        'kind=${openParsed.kind.name} msg=${openParsed.message}',
      );

      final success = _isUnlockSuccess(openParsed);
      BleLog.d(
        '[BleUnlockEngine] Unlock Result success=$success '
        'kind=${openParsed.kind.name}',
      );
      if (!success) {
        await disconnect();
        return UnlockResult.fail(
          stage: 'open',
          message: openParsed.message ?? 'Unlock failed',
          openResponse: openParsed,
        );
      }

      onStage?.call('success');
      final result = UnlockResult.ok(
        stage: 'complete',
        message: 'Locker Opened Successfully',
        deviceId: linked.device.id,
        deviceName: linked.device.name,
        mtu: linked.mtu,
        openResponse: openParsed,
      );
      await disconnect();
      return result;
    } on TimeoutException catch (e) {
      await disconnect();
      final msg = e.message ?? e.toString();
      final stage = msg.toLowerCase().contains('scan')
          ? 'scan'
          : msg.toLowerCase().contains('notification')
              ? 'open_timeout'
              : msg.toLowerCase().contains('connect')
                  ? 'connect'
                  : 'timeout';
      BleLog.e('[BleUnlockEngine] Unlock Result FAIL stage=$stage $msg');
      return UnlockResult.fail(
        stage: stage,
        message: _friendlyTimeout(msg),
        error: e,
        openResponse: openParsed,
      );
    } catch (e) {
      await disconnect();
      BleLog.e('[BleUnlockEngine] Unlock Result FAIL', e);
      return UnlockResult.fail(
        stage: 'unexpected',
        message: _friendlyError(e),
        error: e,
        openResponse: openParsed,
      );
    }
  }

  static void _logUnlockRequest(UnlockPacketRequest request) {
    BleLog.d('── BleUnlockEngine.unlockOpen (Phase 20) ───────');
    BleLog.d('Order ID: ${request.orderId}');
    BleLog.d('Locker ID: ${request.lockerId}');
    BleLog.d('Terminal: ${request.terminalNumber}');
    BleLog.d('Port: ${request.port}');
    BleLog.d('Boxes: ${request.effectiveBoxNumbers}');
    BleLog.d('Item ID: ${request.itemId ?? ''}');
    BleLog.d('Transaction ID: ${request.transactionId}');
    BleLog.d('──────────────────────────────────────────────');
  }

  static bool _isUnlockSuccess(ParsedBleResponse parsed) {
    if (parsed.kind == BleResponseKind.unlockSuccess ||
        parsed.kind == BleResponseKind.ack ||
        parsed.opened == true) {
      return true;
    }
    // Firmware may return a short/unknown status; treat non-NACK as OK
    // once a notify arrives after a valid 32-byte OPEN write (Demo-proven).
    return parsed.kind != BleResponseKind.nack &&
        parsed.kind != BleResponseKind.unlockFailure &&
        parsed.kind != BleResponseKind.error &&
        parsed.kind != BleResponseKind.authRejected;
  }

  static String _friendlyTimeout(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('scan')) return 'Device not found';
    if (lower.contains('notification')) return 'Notification timeout';
    if (lower.contains('connect')) return 'Unable to connect';
    return msg;
  }

  static String _friendlyError(Object e) {
    final text = e.toString();
    final lower = text.toLowerCase();
    if (lower.contains('device not found')) return 'Device not found';
    if (lower.contains('unable to connect') || lower.contains('connection')) {
      return 'Unable to connect';
    }
    if (lower.contains('write failed')) return 'Write failed';
    if (lower.contains('notification timeout')) return 'Notification timeout';
    return text;
  }

  static String _hex(Uint8List bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join(' ');
}
