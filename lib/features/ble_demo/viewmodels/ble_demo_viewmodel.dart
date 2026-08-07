import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ble/ble.dart';
import '../models/ble_demo_packet_request.dart';

/// One row in the BLE Demo log panel.
class BleDemoLogEntry {
  const BleDemoLogEntry({
    required this.message,
    required this.at,
    this.isError = false,
  });

  final String message;
  final DateTime at;
  final bool isError;
}

/// Last notification shown in the Received Data panel.
class BleDemoReceivedData {
  const BleDemoReceivedData({
    required this.hex,
    required this.ascii,
    required this.length,
    required this.timestamp,
    this.parsedKind,
    this.parsedMessage,
  });

  final String hex;
  final String ascii;
  final int length;
  final DateTime timestamp;
  final String? parsedKind;
  final String? parsedMessage;
}

class BleDemoState {
  const BleDemoState({
    this.devices = const [],
    this.connectionLabel = 'Disconnected',
    this.connected = false,
    this.busy = false,
    this.scanning = false,
    this.mtu,
    this.logs = const [],
    this.error,
    this.lockerDeviceName = 'LKRM-V2',
    this.commandKind = BleDemoCommandKind.open,
    this.customOpcode = 0xFF,
    this.terminalNumber = 1,
    this.portNumber = 1,
    this.boxNumber = 1,
    this.orderId = '',
    this.itemId = '',
    this.transactionId = '',
    this.lastPacketHex,
    this.lastPacketBytes,
    this.lastPacketLength,
    this.received,
    this.writeSucceeded,
  });

  final List<BleDevice> devices;
  final String connectionLabel;
  final bool connected;
  final bool busy;
  final bool scanning;
  final int? mtu;
  final List<BleDemoLogEntry> logs;
  final String? error;

  final String lockerDeviceName;
  final BleDemoCommandKind commandKind;
  final int customOpcode;
  final int terminalNumber;
  final int portNumber;
  final int boxNumber;
  final String orderId;
  final String itemId;
  final String transactionId;

  final String? lastPacketHex;
  final List<int>? lastPacketBytes;
  final int? lastPacketLength;
  final BleDemoReceivedData? received;
  final bool? writeSucceeded;

  int get effectiveCommand => commandKind == BleDemoCommandKind.custom
      ? customOpcode & 0xff
      : commandKind.defaultOpcode;

  BleDemoPacketRequest get packetRequest => BleDemoPacketRequest(
        command: effectiveCommand,
        port: portNumber,
        boxNumber: boxNumber,
        terminalNumber: terminalNumber,
        orderId: orderId,
        itemId: itemId,
        transactionId: transactionId,
      );

  BleDemoState copyWith({
    List<BleDevice>? devices,
    String? connectionLabel,
    bool? connected,
    bool? busy,
    bool? scanning,
    int? mtu,
    bool clearMtu = false,
    List<BleDemoLogEntry>? logs,
    String? error,
    bool clearError = false,
    String? lockerDeviceName,
    BleDemoCommandKind? commandKind,
    int? customOpcode,
    int? terminalNumber,
    int? portNumber,
    int? boxNumber,
    String? orderId,
    String? itemId,
    String? transactionId,
    String? lastPacketHex,
    List<int>? lastPacketBytes,
    int? lastPacketLength,
    BleDemoReceivedData? received,
    bool clearReceived = false,
    bool? writeSucceeded,
    bool clearWriteSucceeded = false,
  }) {
    return BleDemoState(
      devices: devices ?? this.devices,
      connectionLabel: connectionLabel ?? this.connectionLabel,
      connected: connected ?? this.connected,
      busy: busy ?? this.busy,
      scanning: scanning ?? this.scanning,
      mtu: clearMtu ? null : (mtu ?? this.mtu),
      logs: logs ?? this.logs,
      error: clearError ? null : (error ?? this.error),
      lockerDeviceName: lockerDeviceName ?? this.lockerDeviceName,
      commandKind: commandKind ?? this.commandKind,
      customOpcode: customOpcode ?? this.customOpcode,
      terminalNumber: terminalNumber ?? this.terminalNumber,
      portNumber: portNumber ?? this.portNumber,
      boxNumber: boxNumber ?? this.boxNumber,
      orderId: orderId ?? this.orderId,
      itemId: itemId ?? this.itemId,
      transactionId: transactionId ?? this.transactionId,
      lastPacketHex: lastPacketHex ?? this.lastPacketHex,
      lastPacketBytes: lastPacketBytes ?? this.lastPacketBytes,
      lastPacketLength: lastPacketLength ?? this.lastPacketLength,
      received: clearReceived ? null : (received ?? this.received),
      writeSucceeded: clearWriteSucceeded
          ? null
          : (writeSucceeded ?? this.writeSucceeded),
    );
  }
}

/// Engineering BLE Demo — local scan/connect/32-byte packet only.
///
/// Does not call payment, unlock JWT, orders, or production Collect APIs.
class BleDemoViewModel extends Notifier<BleDemoState> {
  static const _builder = RealPacketBuilder();
  static final _parser = PacketParser();

  StreamSubscription<bool>? _connSub;

  LockerService get _locker => ref.read(lockerServiceProvider);

  BleConnectionManager get _ble => BleConnectionManager(
        connection: _locker.connectionManager,
        config: _locker.config,
      );

  FlutterBlueTransport? get _fbp {
    final t = _locker.transport;
    return t is FlutterBlueTransport ? t : null;
  }

  @override
  BleDemoState build() {
    ref.onDispose(() {
      _connSub?.cancel();
    });
    ref.listen<BleConfig>(bleConfigProvider, (prev, next) {
      state = const BleDemoState();
      Future.microtask(_attach);
    });
    Future.microtask(_attach);
    return const BleDemoState();
  }

  void _attach() {
    _connSub?.cancel();
    _connSub = _locker.transport.connectionStream.listen((connected) {
      if (!connected && state.connected) {
        _log('Disconnect');
        state = state.copyWith(
          connected: false,
          connectionLabel: 'Disconnected',
          clearMtu: true,
        );
      }
    });
  }

  void _log(String message, {bool isError = false}) {
    final entry = BleDemoLogEntry(
      message: message,
      at: DateTime.now(),
      isError: isError,
    );
    if (isError) {
      BleLog.e('[BLE-DEMO] $message');
    } else {
      BleLog.d('[BLE-DEMO] $message');
    }
    final next = [...state.logs, entry];
    // Keep UI responsive — cap log buffer.
    final trimmed =
        next.length > 200 ? next.sublist(next.length - 200) : next;
    state = state.copyWith(logs: trimmed);
  }

  void updateLockerDeviceName(String v) =>
      state = state.copyWith(lockerDeviceName: v);

  void updateCommandKind(BleDemoCommandKind kind) =>
      state = state.copyWith(commandKind: kind);

  void updateCustomOpcode(int opcode) =>
      state = state.copyWith(customOpcode: opcode & 0xff);

  void updateTerminal(int v) => state = state.copyWith(terminalNumber: v);

  void updatePort(int v) => state = state.copyWith(portNumber: v);

  void updateBox(int v) => state = state.copyWith(boxNumber: v);

  void updateOrderId(String v) => state = state.copyWith(orderId: v);

  void updateItemId(String v) => state = state.copyWith(itemId: v);

  void updateTransactionId(String v) =>
      state = state.copyWith(transactionId: v);

  void clearLogs() => state = state.copyWith(logs: const []);

  /// SCAN — list nearby devices (prefer Real BLE for firmware testing).
  Future<void> scan() async {
    state = state.copyWith(
      busy: true,
      scanning: true,
      clearError: true,
      devices: const [],
    );
    _log('Scan started (target=${state.lockerDeviceName})');
    try {
      final devices = await _locker.scanForLockers().timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          throw TimeoutException('BLE scan timed out after 25s');
        },
      );
      final target = state.lockerDeviceName.trim().toLowerCase();
      final matches = devices
          .where(
            (d) =>
                d.isTargetLocker ||
                d.name.toLowerCase().contains(target) ||
                d.name.toLowerCase() == target,
          )
          .length;
      _log('Scan found ${devices.length} device(s), $matches target match(es)');
      state = state.copyWith(
        devices: devices,
        busy: false,
        scanning: false,
        error: devices.isEmpty
            ? 'Scan finished with 0 devices — check Bluetooth + permissions'
            : matches == 0
                ? 'No ${state.lockerDeviceName} found in ${devices.length} device(s)'
                : null,
        clearError: matches > 0,
      );
    } catch (e) {
      _log('Errors: $e', isError: true);
      state = state.copyWith(
        busy: false,
        scanning: false,
        error: e.toString(),
      );
    }
  }

  /// CONNECT — Scan → Find LKRM-V2 → Connect → MTU → Discover → Notify.
  Future<void> connect() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      _log('Scan');
      state = state.copyWith(scanning: true, connectionLabel: 'Scanning');
      final devices = await _locker.scanForLockers().timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          throw TimeoutException('BLE scan timed out after 25s');
        },
      );
      state = state.copyWith(devices: devices, scanning: false);

      final targetName = state.lockerDeviceName.trim();
      final device = _findTarget(devices, targetName);
      if (device == null) {
        throw StateError(
          'Find $targetName — not found among ${devices.length} device(s)',
        );
      }
      _log('Find $targetName → ${device.name} (${device.id})');

      _log('Connect');
      state = state.copyWith(connectionLabel: 'Connecting');
      await _ble.connect(device);

      final fbp = _fbp;
      final mtu = fbp?.lastMtu ?? _locker.currentConnection.mtu;
      _log('Connected');
      _log('MTU ${mtu ?? _locker.config.desiredMtu}');

      final services = fbp?.discoveredServices ?? const <GattServiceInfo>[];
      _log('Services ${services.length}');
      for (final s in services) {
        _log('  Service ${s.uuid}');
        for (final c in s.characteristics) {
          _log('  Characteristics ${c.uuid} ${c.properties}');
        }
      }
      final notifyOn =
          fbp?.pipelineNotifyEnabled ?? fbp?.linkState.notificationsEnabled;
      _log('Notify enabled ${notifyOn == true ? 'YES' : '—'}');

      state = state.copyWith(
        busy: false,
        connected: true,
        connectionLabel: 'CONNECTED',
        mtu: mtu,
        clearError: true,
      );
    } catch (e) {
      _log('Errors: $e', isError: true);
      state = state.copyWith(
        busy: false,
        scanning: false,
        connected: false,
        connectionLabel: 'Disconnected',
        error: e.toString(),
      );
    }
  }

  BleDevice? _findTarget(List<BleDevice> devices, String targetName) {
    final needle = targetName.toLowerCase();
    // Prefer explicit name match, then isTargetLocker via BleConnectionManager.
    for (final d in devices) {
      if (d.name.toLowerCase() == needle) return d;
    }
    for (final d in devices) {
      if (d.name.toLowerCase().contains(needle)) return d;
    }
    final selected = _ble.selectLockerDevice(
      devices.where((d) => d.isTargetLocker).toList(),
    );
    if (selected != null) return selected;
    return _ble.selectLockerDevice(devices);
  }

  Future<void> disconnect() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _locker.disconnectSafely();
      _log('Disconnect');
      state = state.copyWith(
        busy: false,
        connected: false,
        connectionLabel: 'Disconnected',
        clearMtu: true,
      );
    } catch (e) {
      _log('Errors: $e', isError: true);
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  /// SEND PACKET — build 32-byte RealPacketBuilder packet → write → wait notify.
  Future<void> sendPacket() async {
    if (!state.connected && !_locker.transport.isConnected) {
      state = state.copyWith(error: 'Not connected — press CONNECT first');
      _log('Errors: Not connected', isError: true);
      return;
    }

    state = state.copyWith(
      busy: true,
      clearError: true,
      clearWriteSucceeded: true,
      clearReceived: true,
    );

    try {
      final request = state.packetRequest;
      final packet = _builder.build(
        command: request.command,
        request: request.toUnlockPacketRequest(),
      );

      assert(packet.length == RealPacketBuilder.packetLength);

      final hex = _hex(packet);
      _log('Packet length ${packet.length}');
      _log('Packet HEX $hex');
      for (var i = 0; i < packet.length; i++) {
        _log(
          'Packet bytes[$i] = 0x${packet[i].toRadixString(16).padLeft(2, '0')} '
          '(${packet[i]})',
        );
      }

      state = state.copyWith(
        lastPacketHex: hex,
        lastPacketBytes: List<int>.from(packet),
        lastPacketLength: packet.length,
      );

      await _ble.writePacket(packet);
      _log('Write success');
      state = state.copyWith(writeSucceeded: true);

      final raw = await _ble.waitForNotification(
        timeout: const Duration(seconds: 8),
      );
      final notifyHex = _hex(raw);
      _log('Notification HEX $notifyHex');

      final ascii = _toAscii(raw);
      final parsed = _parser.parse(raw);
      final received = BleDemoReceivedData(
        hex: notifyHex,
        ascii: ascii,
        length: raw.length,
        timestamp: DateTime.now(),
        parsedKind: parsed.kind.name,
        parsedMessage: parsed.message,
      );
      state = state.copyWith(
        busy: false,
        received: received,
      );
    } catch (e) {
      _log('Errors: $e', isError: true);
      state = state.copyWith(
        busy: false,
        writeSucceeded: state.writeSucceeded,
        error: e.toString(),
      );
    }
  }

  static String _hex(Uint8List bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join(' ');

  static String _toAscii(Uint8List bytes) {
    final buf = StringBuffer();
    for (final b in bytes) {
      if (b >= 0x20 && b <= 0x7e) {
        buf.writeCharCode(b);
      } else {
        buf.write('.');
      }
    }
    return buf.toString();
  }
}

final bleDemoViewModelProvider =
    NotifierProvider<BleDemoViewModel, BleDemoState>(BleDemoViewModel.new);
