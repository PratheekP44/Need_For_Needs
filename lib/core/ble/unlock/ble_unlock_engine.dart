import 'dart:async';
import 'dart:typed_data';

import '../locker/locker_service.dart';
import '../managers/ble_connection_manager.dart';
import '../managers/timeout_manager.dart';
import '../models/ble_device.dart';
import '../protocol/final_unlock_packet_builder.dart';
import '../protocol/packet_parser.dart';
import '../protocol/packet_types.dart';
import '../protocol/parsed_ble_response.dart';
import '../protocol/real_packet_builder.dart';
import '../transport/ble_log.dart';
import '../transport/collect_ble_profiler.dart';
import '../transport/flutter_blue_transport.dart';

/// Result of the proven Demo connect pipeline (scan → connect → MTU → GATT → notify).
class BleUnlockConnectResult {
  const BleUnlockConnectResult({
    required this.device,
    this.mtu,
    this.services = const [],
    this.notifyEnabled = false,
    this.usedSessionCache = false,
  });

  final BleDevice device;
  final int? mtu;
  final List<GattServiceInfo> services;
  final bool notifyEnabled;
  final bool usedSessionCache;
}

/// Shared BLE unlock engine used by production Collect.
///
/// Collect OPEN uses [FinalUnlockPacketBuilder] (Phase 32).
/// [RealPacketBuilder] remains for Demo / legacy [buildPacket].
class BleUnlockEngine {
  BleUnlockEngine({
    required LockerService locker,
    RealPacketBuilder? packetBuilder,
    FinalUnlockPacketBuilder? finalPacketBuilder,
    PacketParser? packetParser,
    TimeoutManager? timeouts,
  })  : _locker = locker,
        _builder = packetBuilder ?? const RealPacketBuilder(),
        _finalBuilder = finalPacketBuilder ?? FinalUnlockPacketBuilder(),
        _parser = packetParser ?? PacketParser(),
        _timeouts = timeouts ?? const TimeoutManager();

  final LockerService _locker;
  final RealPacketBuilder _builder;
  final FinalUnlockPacketBuilder _finalBuilder;
  final PacketParser _parser;
  final TimeoutManager _timeouts;

  static const String defaultTargetName = 'LKRM-V2';

  /// Session-only cache of the last successfully connected locker.
  /// Identity remains advertised name (configurable); the remote id is only
  /// reused within this app process for faster reconnect — never hardcoded.
  BleDevice? _sessionDevice;
  String _sessionTargetName = defaultTargetName;

  LockerService get locker => _locker;

  BleConnectionManager get connection => BleConnectionManager(
        connection: _locker.connectionManager,
        config: _locker.config,
      );

  RealPacketBuilder get packetBuilder => _builder;
  FinalUnlockPacketBuilder get finalPacketBuilder => _finalBuilder;
  PacketParser get packetParser => _parser;

  bool get isConnected =>
      _locker.transport.isConnected || connection.isConnected;

  FlutterBlueTransport? get _fbp {
    final t = _locker.transport;
    return t is FlutterBlueTransport ? t : null;
  }

  /// Clear session reconnect cache (tests / forced fresh scan).
  void clearSessionCache() {
    _sessionDevice = null;
  }

  /// Scan nearby lockers (production Collect path).
  ///
  /// Phase 31: short ceiling ([BleConfig.scanTimeout], typically 5s) and
  /// [stopOnTarget] so we cancel as soon as LKRM-V2 is seen.
  Future<List<BleDevice>> scan({
    Duration? timeout,
    bool stopOnTarget = true,
  }) async {
    BleLog.d('[BleUnlockEngine] Scan stopOnTarget=$stopOnTarget');
    await connection.ensurePermissions();
    final wait = timeout ?? _locker.config.scanTimeout;
    return connection.scan(timeout: wait, stopOnTarget: stopOnTarget).timeout(
      wait + const Duration(seconds: 2),
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

  bool _sessionMatches(String targetName) {
    final cached = _sessionDevice;
    if (cached == null) return false;
    final needle = targetName.trim().toLowerCase();
    if (needle.isEmpty) return false;
    final name = cached.name.toLowerCase();
    return name == needle ||
        name.contains(needle) ||
        _sessionTargetName.toLowerCase() == needle;
  }

  void _rememberSession(BleDevice device, String targetName) {
    _sessionDevice = device;
    _sessionTargetName = targetName;
    BleLog.d(
      '[Phase31] SESSION_CACHE remember name=${device.name} '
      '(id retained for this app session only)',
    );
  }

  BleUnlockConnectResult _connectResult(
    BleDevice device, {
    required bool usedSessionCache,
  }) {
    final fbp = _fbp;
    final mtu = fbp?.lastMtu ?? _locker.currentConnection.mtu;
    final services = fbp?.discoveredServices ?? const <GattServiceInfo>[];
    final notifyOn = fbp?.pipelineNotifyEnabled ??
        fbp?.linkState.notificationsEnabled ??
        true;
    return BleUnlockConnectResult(
      device: device,
      mtu: mtu,
      services: services,
      notifyEnabled: notifyOn,
      usedSessionCache: usedSessionCache,
    );
  }

  Future<void> _connectDevice(
    BleDevice device, {
    CollectBleProfiler? timing,
  }) async {
    timing?.mark('CONNECT_START');
    BleLog.d('[Phase31] CONNECT_START name=${device.name}');
    await connection.connect(device).timeout(
      // Full pipeline = GATT connect + MTU + discover + notify.
      // Per-attempt connect timeout stays at config.connectTimeout; this is
      // only the outer Collect budget (retries + pipeline).
      _locker.config.connectTimeout + const Duration(seconds: 12),
      onTimeout: () {
        throw TimeoutException('Unable to connect (timeout)');
      },
    );
    timing?.mark('CONNECTED');
    BleLog.d('[Phase31] CONNECTED');

    // Pipeline already timed MTU / discovery / notify internally — dump it.
    connection.inner.lastPipelineTimer?.report(
      headline: 'Phase31 post-connect pipeline (MTU/DISCOVERY/NOTIFY)',
    );
  }

  /// Scan → Find device by name → Connect → MTU → Discover → Enable notifications.
  ///
  /// Phase 31: try session reconnect first; else short scan with early stop.
  Future<BleUnlockConnectResult> connect({
    String targetDeviceName = defaultTargetName,
    void Function(String stage)? onStage,
    CollectBleProfiler? timing,
  }) async {
    final targetName = targetDeviceName.trim().isEmpty
        ? defaultTargetName
        : targetDeviceName.trim();

    // ── Session reconnect (fallback to scan on any failure) ─────────────
    if (_sessionMatches(targetName)) {
      final cached = _sessionDevice!;
      onStage?.call('connect');
      BleLog.d(
        '[Phase31] SESSION_RECONNECT attempt name=${cached.name}',
      );
      try {
        await _connectDevice(cached, timing: timing);
        _rememberSession(cached, targetName);
        final result = _connectResult(cached, usedSessionCache: true);
        _logConnected(result);
        onStage?.call('connected');
        return result;
      } catch (e) {
        BleLog.d('[Phase31] SESSION_RECONNECT failed — short scan fallback: $e');
        await disconnect();
        _sessionDevice = null;
      }
    }

    onStage?.call('scan');
    BleLog.d('[BleUnlockEngine] Scan');
    timing?.mark('SCAN_START');
    final devices = await scan(
      timeout: _locker.config.scanTimeout,
      stopOnTarget: true,
    );
    timing?.mark('SCAN_STOP');

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
    BleLog.d('[Phase31] DEVICE_FOUND name=${device.name}');

    onStage?.call('connect');
    BleLog.d('[BleUnlockEngine] Connect');
    try {
      await _connectDevice(device, timing: timing);
    } on TimeoutException {
      await disconnect();
      rethrow;
    } catch (e) {
      await disconnect();
      throw StateError('Unable to connect: $e');
    }

    _rememberSession(device, targetName);
    final result = _connectResult(device, usedSessionCache: false);
    _logConnected(result);
    onStage?.call('connected');
    return result;
  }

  void _logConnected(BleUnlockConnectResult result) {
    BleLog.d('[BleUnlockEngine] Connected');
    BleLog.d('[BleUnlockEngine] MTU ${result.mtu ?? _locker.config.desiredMtu}');
    BleLog.d('[BleUnlockEngine] Services ${result.services.length}');
    for (final s in result.services) {
      BleLog.d('[BleUnlockEngine]   Service ${s.uuid}');
      for (final c in s.characteristics) {
        BleLog.d(
          '[BleUnlockEngine]   Characteristics ${c.uuid} ${c.properties}',
        );
      }
    }
    BleLog.d(
      '[BleUnlockEngine] Notify enabled ${result.notifyEnabled ? 'YES' : '—'}',
    );
  }

  /// Legacy / Demo: fixed Phase-20 packet via [RealPacketBuilder].
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

  /// Production Collect: FINAL 32-byte packet (Command 0x01 + order Port).
  ///
  /// Boxes come only from [request.effectiveBoxNumbers] (current order).
  Uint8List buildCollectPacket(UnlockPacketRequest request) {
    final boxes = request.effectiveBoxNumbers;
    final packet = _finalBuilder.buildCollect(
      boxNumbers: boxes,
      orderId: request.orderId,
    );
    assert(packet.length == FinalUnlockPacketBuilder.packetLength);
    assert(packet[0] == FirmwareCommand.open);
    BleLog.d(
      '[BleUnlockEngine] COLLECT FINAL packet len=${packet.length} '
      'boxes=$boxes HEX=${_hex(packet)}',
    );
    return packet;
  }

  /// Write characteristic → wait for notification → parse.
  ///
  /// Phase 30: arm the notification waiter *before* the GATT write.
  /// [notificationStream] is broadcast (no buffer). With write-with-response,
  /// firmware often NOTIFYs during the ATT round-trip — listening only after
  /// write returns drops the ACK and Collect never reaches SUCCESS.
  Future<ParsedBleResponse> writeAndWait({
    required Uint8List packet,
    Duration? timeout,
    CollectBleProfiler? timing,
  }) async {
    if (!isConnected) {
      throw StateError('Write failed — not connected');
    }
    // Isolate from builder buffer — transport also copies again.
    final wire = Uint8List.fromList(packet);
    BleLog.d(
      '[BleUnlockEngine] writeAndWait ORIGINAL length=${wire.length} '
      'HEX=${_hex(wire)}',
    );

    final wait =
        timeout ?? _timeouts.responseTimeout(BlePacketType.openBox);
    // Same ordering as [BleProtocol._sendAndWait]: listen, then write.
    final pending = connection.waitForNotification(timeout: wait);

    try {
      timing?.mark('WRITE_START');
      BleLog.d('[Phase31] WRITE_START');
      await connection.writePacket(wire);
      timing?.mark('WRITE_COMPLETE');
      BleLog.d('[Phase31] WRITE_COMPLETE');
      BleLog.d('[BleUnlockEngine] Write success');
    } catch (e) {
      BleLog.e('[BleUnlockEngine] Write failed', e);
      // Ignore the armed waiter so it does not leak unhandled errors.
      unawaited(pending.then<void>((_) {}, onError: (_) {}));
      throw StateError('Write failed: $e');
    }

    try {
      final raw = await pending;
      timing?.mark('RESPONSE_RECEIVED');
      BleLog.d('[Phase31] RESPONSE_RECEIVED len=${raw.length}');
      BleLog.d(
        '[BleUnlockEngine] Notification HEX ${_hex(raw)}',
      );
      return _parser.parse(raw);
    } on TimeoutException catch (e) {
      BleLog.e('[BleUnlockEngine] Notification timeout', e);
      throw TimeoutException('Notification timeout');
    }
  }

  /// Build + write + wait (Demo SEND PACKET — still Phase-20 [RealPacketBuilder]).
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
    final timing = CollectBleProfiler();
    _logUnlockRequest(request);

    ParsedBleResponse? openParsed;
    BleUnlockConnectResult? linked;

    try {
      linked = await connect(
        targetDeviceName: targetDeviceName,
        onStage: onStage,
        timing: timing,
      );

      onStage?.call('open');
      // Phase 32 — Collect sends FINAL packet (Command 0x01 + current-order Port).
      final packet = buildCollectPacket(request);
      BleLog.d('[BleUnlockEngine] Packet HEX ${_hex(packet)}');
      openParsed = await writeAndWait(packet: packet, timing: timing);

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
        timing.mark('UNLOCK_FAIL');
        timing.report(success: false, note: openParsed.message);
        await disconnect();
        return UnlockResult.fail(
          stage: 'open',
          message: openParsed.message ?? 'Unlock failed',
          openResponse: openParsed,
        );
      }

      timing.mark('UNLOCK_SUCCESS');
      BleLog.d('[Phase31] UNLOCK_SUCCESS');
      timing.report(
        success: true,
        note: linked.usedSessionCache ? 'session_reconnect' : 'short_scan',
      );
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
      timing.mark('UNLOCK_FAIL');
      timing.report(success: false, note: e.message);
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
      timing.mark('UNLOCK_FAIL');
      timing.report(success: false, note: e.toString());
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
    BleLog.d('── BleUnlockEngine.unlockOpen (Phase 32 FINAL packet) ──');
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
