import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ble/ble.dart';

/// Phase 13A — scan / connect / discover / notify only (no auth, no packets).
class BleDebugState {
  const BleDebugState({
    this.devices = const [],
    this.connectionLabel = 'Disconnected',
    this.rssi,
    this.mtu,
    this.services = const [],
    this.connectedAt,
    this.error,
    this.busy = false,
    this.serviceFound = false,
    this.char1Found = false,
    this.char4Found = false,
    this.notificationsEnabled = false,
    this.scanning = false,
  });

  final List<BleDevice> devices;
  final String connectionLabel;
  final int? rssi;
  final int? mtu;
  final List<GattServiceInfo> services;
  final DateTime? connectedAt;
  final String? error;
  final bool busy;
  final bool serviceFound;
  final bool char1Found;
  final bool char4Found;
  final bool notificationsEnabled;
  final bool scanning;

  BleDebugState copyWith({
    List<BleDevice>? devices,
    String? connectionLabel,
    int? rssi,
    int? mtu,
    List<GattServiceInfo>? services,
    DateTime? connectedAt,
    String? error,
    bool clearError = false,
    bool? busy,
    bool? serviceFound,
    bool? char1Found,
    bool? char4Found,
    bool? notificationsEnabled,
    bool? scanning,
    bool clearConnectedAt = false,
    bool clearRssi = false,
    bool clearMtu = false,
  }) {
    return BleDebugState(
      devices: devices ?? this.devices,
      connectionLabel: connectionLabel ?? this.connectionLabel,
      rssi: clearRssi ? null : (rssi ?? this.rssi),
      mtu: clearMtu ? null : (mtu ?? this.mtu),
      services: services ?? this.services,
      connectedAt: clearConnectedAt ? null : (connectedAt ?? this.connectedAt),
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
      serviceFound: serviceFound ?? this.serviceFound,
      char1Found: char1Found ?? this.char1Found,
      char4Found: char4Found ?? this.char4Found,
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      scanning: scanning ?? this.scanning,
    );
  }
}

class BleDebugController extends Notifier<BleDebugState> {
  StreamSubscription<LockerState>? _stateSub;
  StreamSubscription<int>? _rssiSub;
  StreamSubscription<List<BleDevice>>? _nearbySub;
  StreamSubscription<BleLinkState>? _linkSub;

  LockerService get _locker => ref.read(lockerServiceProvider);

  FlutterBlueTransport? get _fbp {
    final t = _locker.transport;
    return t is FlutterBlueTransport ? t : null;
  }

  @override
  BleDebugState build() {
    ref.onDispose(() {
      _stateSub?.cancel();
      _rssiSub?.cancel();
      _nearbySub?.cancel();
      _linkSub?.cancel();
    });
    ref.listen<BleConfig>(bleConfigProvider, (prev, next) {
      state = const BleDebugState();
      Future.microtask(_attach);
    });
    Future.microtask(_attach);
    return const BleDebugState();
  }

  void _attach() {
    _stateSub?.cancel();
    _stateSub = _locker.stateStream.listen((s) {
      state = state.copyWith(connectionLabel: _labelFor(s));
    });
    state = state.copyWith(connectionLabel: _labelFor(_locker.state));

    _nearbySub?.cancel();
    _nearbySub = _locker.nearbyLockersStream.listen((devices) {
      state = state.copyWith(devices: devices);
    });

    _rssiSub?.cancel();
    _rssiSub = _locker.transport.rssiStream.listen((rssi) {
      state = state.copyWith(rssi: rssi);
    });

    _linkSub?.cancel();
    final fbp = _fbp;
    if (fbp != null) {
      _linkSub = fbp.linkStateStream.listen(_applyLink);
      _applyLink(fbp.linkState);
    }
  }

  void _applyLink(BleLinkState link) {
    state = state.copyWith(
      notificationsEnabled: link.notificationsEnabled,
      serviceFound: link.servicesDiscovered || state.serviceFound,
      connectionLabel: link.hasError
          ? 'Error'
          : link.isReady
              ? 'Ready'
              : link.isConnected
                  ? 'Connected'
                  : state.connectionLabel,
      error: link.hasError ? (link.lastError ?? state.error) : state.error,
      clearError: !link.hasError && state.error != null && link.isReady,
    );
  }

  String _labelFor(LockerState s) {
    switch (s) {
      case LockerState.scanning:
        return 'Scanning';
      case LockerState.connecting:
        return 'Connecting';
      case LockerState.connected:
      case LockerState.authenticated:
      case LockerState.authenticating:
      case LockerState.opening:
      case LockerState.waitingResponse:
      case LockerState.success:
        return 'Connected';
      case LockerState.reconnecting:
        return 'Reconnecting';
      case LockerState.failure:
        return 'Disconnected';
      case LockerState.disconnected:
        return 'Disconnected';
    }
  }

  /// Scan nearby devices filtered by CC2340 Service UUID.
  Future<void> scan() async {
    state = state.copyWith(
      busy: true,
      scanning: true,
      clearError: true,
      devices: const [],
    );
    try {
      if (!_locker.config.isRealBle) {
        // Virtual MCU still supports a single advertised device for UI bring-up.
        final devices = await _locker.scanForLockers();
        state = state.copyWith(
          devices: devices,
          busy: false,
          scanning: false,
        );
        return;
      }
      final devices = await _locker.scanForLockers();
      state = state.copyWith(
        devices: devices,
        busy: false,
        scanning: false,
      );
    } catch (e) {
      state = state.copyWith(
        busy: false,
        scanning: false,
        error: e.toString(),
      );
    }
  }

  /// Connect → MTU → discover GATT → subscribe to Char 4 notifications.
  Future<void> connect(BleDevice device) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _locker.connect(device);
      final snapshot = _gattSnapshot();
      final fbp = _fbp;
      final serviceUuid = _locker.config.serviceUuid.str.toLowerCase();
      final serviceFound = snapshot.any(
        (s) => s.uuid.toLowerCase() == serviceUuid,
      );
      state = state.copyWith(
        busy: false,
        connectionLabel: fbp?.linkState.isReady == true ? 'Ready' : 'Connected',
        mtu: fbp?.lastMtu ?? _locker.currentConnection.mtu,
        services: snapshot,
        connectedAt: fbp?.connectedAt ?? DateTime.now(),
        char1Found: fbp?.hasCommandCharacteristic ??
            snapshot.any((s) => s.characteristics.any((c) => c.isCommand)),
        char4Found: fbp?.hasStatusCharacteristic ??
            snapshot.any((s) => s.characteristics.any((c) => c.isStatus)),
        notificationsEnabled:
            fbp?.linkState.notificationsEnabled ?? true,
        serviceFound: serviceFound,
        rssi: device.rssi ?? state.rssi,
      );
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  List<GattServiceInfo> _gattSnapshot() {
    final fbp = _fbp;
    if (fbp != null && fbp.discoveredServices.isNotEmpty) {
      return fbp.discoveredServices;
    }
    // Virtual MCU / mock: surface configured GATT profile for the debug UI.
    final c = _locker.config;
    return [
      GattServiceInfo(
        uuid: c.serviceUuid.str,
        characteristics: [
          GattCharacteristicInfo(
            uuid: c.writeCharacteristicUuid.str,
            properties: 'WRITE|WRITE_NO_RESP',
            isCommand: true,
          ),
          GattCharacteristicInfo(
            uuid: c.notifyCharacteristicUuid.str,
            properties: 'NOTIFY|READ',
            isStatus: true,
          ),
        ],
      ),
    ];
  }

  Future<void> disconnect() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _locker.disconnectSafely();
      state = state.copyWith(
        busy: false,
        connectionLabel: 'Disconnected',
        clearConnectedAt: true,
        clearRssi: true,
        clearMtu: true,
        services: const [],
        char1Found: false,
        char4Found: false,
        notificationsEnabled: false,
        serviceFound: false,
      );
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  String connectionDurationLabel() {
    final started = state.connectedAt;
    if (started == null) return '—';
    final d = DateTime.now().difference(started);
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}m ${s}s';
  }
}

final bleDebugProvider =
    NotifierProvider<BleDebugController, BleDebugState>(BleDebugController.new);
