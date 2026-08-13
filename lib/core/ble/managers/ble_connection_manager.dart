import 'dart:async';
import 'dart:typed_data';

import '../config/ble_config.dart';
import '../models/ble_device.dart';
import '../transport/ble_log.dart';
import '../transport/ble_transport.dart';
import '../transport/flutter_blue_transport.dart';
import 'connection_manager.dart';

/// Phase 14 connection façade over existing [ConnectionManager] / [BleTransport].
///
/// Responsibilities: connect, write packet, wait for write confirmation,
/// expose notification stream, timeouts, retries (via inner manager),
/// connection state, and clean disconnect. No UI logic.
class BleConnectionManager {
  BleConnectionManager({
    required ConnectionManager connection,
    required BleConfig config,
  })  : _connection = connection,
        _config = config;

  final ConnectionManager _connection;
  final BleConfig _config;

  ConnectionManager get inner => _connection;
  BleTransport get transport => _connection.transport;
  bool get isConnected => _connection.isConnected;
  BleDevice? get currentDevice => _connection.currentDevice;
  Stream<bool> get connectionStream => _connection.connectionStream;
  Stream<Uint8List> get notificationStream => _connection.notificationStream;
  Stream<int> get rssiStream => _connection.rssiStream;

  Future<void> ensurePermissions() => _connection.ensurePermissions();

  Future<List<BleDevice>> scan({
    Duration? timeout,
    bool stopOnTarget = false,
  }) async {
    BleLog.d('BleConnectionManager.scan stopOnTarget=$stopOnTarget');
    return _connection.scan(timeout: timeout, stopOnTarget: stopOnTarget);
  }

  Future<void> stopScan() => _connection.stopScan();

  /// Prefer LKRM-V2 / service-UUID targets, then strongest RSSI.
  BleDevice? selectLockerDevice(List<BleDevice> devices) {
    if (devices.isEmpty) return null;
    final targets = devices.where((d) => d.isTargetLocker).toList();
    final pool = targets.isNotEmpty ? targets : devices;
    pool.sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    final chosen = pool.first;
    BleLog.d(
      'BleConnectionManager.select device=${chosen.name} id=${chosen.id} '
      'target=${chosen.isTargetLocker} rssi=${chosen.rssi}',
    );
    return chosen;
  }

  /// Find by bluetooth address / remoteId when backend provides one.
  BleDevice? findByAddress(List<BleDevice> devices, String? address) {
    if (address == null || address.isEmpty) return null;
    final needle = address.toLowerCase();
    for (final d in devices) {
      if (d.id.toLowerCase() == needle) return d;
    }
    return null;
  }

  Future<void> connect(
    BleDevice device, {
    Duration? timeout,
  }) async {
    BleLog.d('Connected? starting connect → ${device.name} (${device.id})');
    await _connection.connect(device);
    final t = transport;
    if (t is FlutterBlueTransport) {
      BleLog.d('Connected YES');
      BleLog.d('MTU ${t.lastMtu ?? _config.desiredMtu}');
      BleLog.d('Services ${t.discoveredServices.length}');
      for (final s in t.discoveredServices) {
        BleLog.d('  Service ${s.uuid}');
        for (final c in s.characteristics) {
          BleLog.d('    Char ${c.uuid} ${c.properties}');
        }
      }
      BleLog.d(
        'Notify Enabled=${t.pipelineNotifyEnabled} '
        'Characteristics Found=${t.pipelineCharacteristicsFound}',
      );
    } else {
      BleLog.d('Connected YES (non-FBP transport)');
    }
  }

  /// Write packet bytes and wait for the GATT write to complete.
  Future<void> writePacket(Uint8List bytes) async {
    if (!_connection.isConnected) {
      throw StateError('Write failed — not connected');
    }
    // Fresh copy so builder / caller buffers cannot be mutated mid-TX.
    final wire = Uint8List.fromList(bytes);
    BleLog.d(
      'Packet Sent (pre-transport) length=${wire.length} '
      'HEX=${_hex(wire)}',
    );
    try {
      await _connection.write(wire).timeout(
        _config.writeTimeout,
        onTimeout: () {
          BleLog.e('Timeout — characteristic write');
          throw TimeoutException(
            'Write timed out after ${_config.writeTimeout}',
          );
        },
      );
      BleLog.d('Write confirmation OK (${wire.length} bytes)');
    } catch (e) {
      BleLog.e('Write failed', e);
      rethrow;
    }
  }

  /// Wait for the next notification (any), with timeout.
  ///
  /// Call this *before* [writePacket]. The underlying stream is broadcast and
  /// does not buffer — events that arrive with no listener are dropped.
  Future<Uint8List> waitForNotification({Duration? timeout}) async {
    final wait = timeout ?? const Duration(seconds: 8);
    BleLog.d('Waiting for notification timeout=${wait.inSeconds}s');
    try {
      final bytes = await notificationStream.first.timeout(wait);
      BleLog.d(
        'Packet Received length=${bytes.length} HEX=${_hex(bytes)}',
      );
      return bytes;
    } on TimeoutException {
      BleLog.e('Timeout — notification');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    BleLog.d('Disconnect cleanly');
    await _connection.disconnect();
  }

  void watchDisconnect(void Function() onLost) {
    _connection.connectionStream.listen((connected) {
      if (!connected) {
        BleLog.d('Connection Lost');
        onLost();
      }
    });
  }

  static String _hex(Uint8List bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join(' ');
}
