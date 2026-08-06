import 'dart:async';
import 'dart:typed_data';

import '../config/ble_config.dart';
import '../models/ble_device.dart';
import '../transport/ble_log.dart';
import '../transport/ble_transport.dart';
import '../transport/flutter_blue_transport.dart';

/// Manages connect / disconnect / reconnect over [BleTransport].
///
/// Production reconnect/retry behavior mirrors SmartAAP BleHandler patterns
/// (budgeted retries, rediscover + renotify) without changing [BleProtocol].
class ConnectionManager {
  ConnectionManager({
    required this.transport,
    required this.config,
    this.onReconnecting,
    this.onReconnected,
  });

  final BleTransport transport;
  final BleConfig config;

  /// Fired when auto-reconnect starts.
  final void Function()? onReconnecting;

  /// Fired after a successful auto-reconnect (+ rediscover).
  final void Function()? onReconnected;

  BleDevice? _current;
  int _reconnectAttempts = 0;
  StreamSubscription<bool>? _connectionSub;
  bool _reconnecting = false;
  bool _pipelineBusy = false;

  BleDevice? get currentDevice => _current;
  bool get isConnected => transport.isConnected;
  bool get isReconnecting => _reconnecting;
  int get reconnectAttempts => _reconnectAttempts;

  Stream<bool> get connectionStream => transport.connectionStream;
  Stream<int> get rssiStream => transport.rssiStream;

  Future<void> ensurePermissions() => transport.ensurePermissions();

  Future<List<BleDevice>> scan({Duration? timeout}) {
    return transport.startScan(
      timeout: timeout ?? config.scanTimeout,
      namePrefix: config.deviceNamePrefix,
    );
  }

  Future<void> stopScan() => transport.stopScan();

  /// Connect + MTU + discover + notifications (Java runToken setup path).
  Future<void> connect(BleDevice device) async {
    if (_pipelineBusy) {
      throw StateError('BLE pipeline busy — wait for current connect/reconnect');
    }
    _pipelineBusy = true;
    try {
      BleLog.d('ConnectionManager.connect ${device.id}');
      await transport.connect(device, timeout: config.connectTimeout);
      _current = device;
      _reconnectAttempts = 0;
      _reconnecting = false;
      await _postConnectPipeline();
      _watchConnection();
    } finally {
      _pipelineBusy = false;
    }
  }

  Future<void> _postConnectPipeline() async {
    final mtu = await transport.requestMtu(config.desiredMtu);
    BleLog.d('Post-connect MTU=$mtu');
    await transport.discoverServices();
    await transport.enableNotifications();
    final t = transport;
    if (t is FlutterBlueTransport && !t.linkState.isReady) {
      throw StateError('BT not ready after pipeline: ${t.linkState}');
    }
  }

  Future<void> disconnect({bool suppressAutoReconnect = true}) async {
    if (suppressAutoReconnect) {
      await _connectionSub?.cancel();
      _connectionSub = null;
    }
    await transport.disconnect();
    if (suppressAutoReconnect) {
      _current = null;
      _reconnectAttempts = 0;
      _reconnecting = false;
    }
  }

  Future<void> write(Uint8List bytes) => transport.write(bytes);

  Stream<Uint8List> get notificationStream => transport.notificationStream;

  Future<int?> readRssi() => transport.readRssi();

  void _watchConnection() {
    _connectionSub?.cancel();
    _connectionSub = transport.connectionStream.listen((connected) async {
      if (connected) {
        _reconnectAttempts = 0;
        if (_reconnecting) {
          _reconnecting = false;
          onReconnected?.call();
        }
        return;
      }
      if (!config.autoReconnect || _current == null) return;
      if (_pipelineBusy) return;
      if (_reconnectAttempts >= config.maxReconnectAttempts) {
        _reconnecting = false;
        BleLog.e('Auto-reconnect budget exhausted');
        return;
      }
      _reconnectAttempts += 1;
      _reconnecting = true;
      onReconnecting?.call();
      BleLog.d(
        'Auto-reconnect attempt $_reconnectAttempts/'
        '${config.maxReconnectAttempts}',
      );
      await Future<void>.delayed(config.reconnectDelay);
      try {
        final device = _current;
        if (device == null) return;
        _pipelineBusy = true;
        await transport.connect(device, timeout: config.connectTimeout);
        await _postConnectPipeline();
        _reconnecting = false;
        onReconnected?.call();
      } catch (e) {
        BleLog.e('Auto-reconnect failed', e);
        // Budgeted retries continue on subsequent disconnects.
      } finally {
        _pipelineBusy = false;
      }
    });
  }

  Future<void> dispose() async {
    await _connectionSub?.cancel();
    await disconnect(suppressAutoReconnect: true);
    await transport.dispose();
  }
}
