import 'dart:async';
import 'dart:typed_data';

import '../config/ble_config.dart';
import '../models/ble_device.dart';
import '../transport/ble_log.dart';
import '../transport/ble_pipeline_timer.dart';
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
  BlePipelineTimer? _timer;

  BleDevice? get currentDevice => _current;
  bool get isConnected => transport.isConnected;
  bool get isReconnecting => _reconnecting;
  int get reconnectAttempts => _reconnectAttempts;
  BlePipelineTimer? get lastPipelineTimer => _timer;

  Stream<bool> get connectionStream => transport.connectionStream;
  Stream<int> get rssiStream => transport.rssiStream;

  Future<void> ensurePermissions() => transport.ensurePermissions();

  Future<List<BleDevice>> scan({
    Duration? timeout,
    bool stopOnTarget = false,
  }) {
    return transport.startScan(
      timeout: timeout ?? config.scanTimeout,
      namePrefix: config.deviceNamePrefix,
      stopOnTarget: stopOnTarget,
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
      _timer = BlePipelineTimer();
      final t = transport;
      if (t is FlutterBlueTransport) {
        t.pipelineTimer = _timer;
      }
      _timer!.mark('CONNECT_BEGIN');
      BleLog.d('ConnectionManager.connect ${device.id}');
      await transport.connect(device, timeout: config.connectTimeout);
      _timer!.mark('CONNECT_ESTABLISHED');
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
    final timer = _timer;
    // Java BleHandler: proceed on each GATT callback — no fixed sleeps.
    // Artificial settles risk firmware idle disconnect (~5s).
    await _maybeSettle(config.postConnectSettle, 'SETTLE_POST_CONNECT', timer);

    timer?.mark('MTU_REQUEST_START');
    BleLog.d('[Phase31] MTU_START desired=${config.desiredMtu}');
    BleLog.d('PIPELINE step=RequestMTU desired=${config.desiredMtu}');
    final mtu = await transport.requestMtu(config.desiredMtu);
    timer?.mark('MTU_COMPLETE mtu=$mtu');
    BleLog.d('[Phase31] MTU_COMPLETE mtu=$mtu');
    await _maybeSettle(config.postMtuSettle, 'SETTLE_POST_MTU', timer);

    timer?.mark('DISCOVER_START');
    BleLog.d('[Phase31] DISCOVERY_START');
    BleLog.d('PIPELINE step=DiscoverServices');
    await transport.discoverServices();
    timer?.mark('SERVICES_DISCOVERED');
    BleLog.d('[Phase31] DISCOVERY_COMPLETE');
    await _maybeSettle(config.postDiscoverSettle, 'SETTLE_POST_DISCOVER', timer);

    timer?.mark('NOTIFY_ENABLE_START');
    BleLog.d('[Phase31] NOTIFICATION_SUBSCRIBE_START');
    BleLog.d('PIPELINE step=EnableNotifyC4');
    await transport.enableNotifications();
    timer?.mark('NOTIFY_ENABLED');
    BleLog.d('[Phase31] NOTIFICATION_SUBSCRIBE');
    // CRITICAL: do not delay here — AUTH must follow immediately (Java parity).
    await _maybeSettle(config.postNotifySettle, 'SETTLE_POST_NOTIFY', timer);

    final t = transport;
    if (t is FlutterBlueTransport) {
      BleLog.d(
        'PIPELINE Ready connected=${t.isConnected} mtu=${t.lastMtu} '
        'services=${t.pipelineServicesFound} '
        'chars=${t.pipelineCharacteristicsFound} '
        'notify=${t.pipelineNotifyEnabled} '
        'link=${t.linkState} t=${timer?.elapsedMs}ms',
      );
      if (!t.linkState.isReady) {
        throw StateError('BT not ready after pipeline: ${t.linkState}');
      }
      // RSSI only after setup — concurrent readRssi during write → GATT 133.
      t.startRssiPollingAfterReady();
    }
    timer?.mark('READY_FOR_AUTH_WRITE');
    BleLog.d(
      'PIPELINE step=ReadyForWriteAUTH_C1 t=${timer?.elapsedMs}ms '
      '(AUTH should fire immediately — no post-notify sleep)',
    );
  }

  Future<void> _maybeSettle(
    Duration delay,
    String label,
    BlePipelineTimer? timer,
  ) async {
    if (delay <= Duration.zero) return;
    BleLog.d('PIPELINE artificial settle $label ${delay.inMilliseconds}ms');
    await Future<void>.delayed(delay);
    timer?.mark(label);
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
        _timer = BlePipelineTimer();
        final t = transport;
        if (t is FlutterBlueTransport) {
          t.pipelineTimer = _timer;
        }
        _timer!.mark('RECONNECT_BEGIN');
        await transport.connect(device, timeout: config.connectTimeout);
        _timer!.mark('CONNECT_ESTABLISHED');
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
