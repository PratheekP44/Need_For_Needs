import 'dart:async';
import 'dart:typed_data';

import 'package:virtual_mcu/virtual_mcu.dart';

import '../config/ble_config.dart';
import '../models/ble_device.dart';
import 'ble_transport.dart';

/// BleTransport adapter over [MCUCore].
///
/// Drop-in replacement for [MockBleTransport]. When real CC2340 firmware
/// ships, replace this class with [FlutterBlueTransport] only — LockerService /
/// BleProtocol stay unchanged.
class VirtualMCUTransport implements BleTransport {
  VirtualMCUTransport({
    BleConfig? config,
    MCUCore? mcu,
    SimulationConfig? simulation,
  })  : _config = config ?? BleConfig.development(),
        _mcu = mcu ??
            MCUCore(
              config: simulation ??
                  SimulationConfig(
                    lockerId: 'LCK-A1',
                    openDelay: const Duration(milliseconds: 80),
                  ),
            ) {
    _outboundSub = _mcu.outboundNotifications.listen((frame) {
      if (_connected) {
        _notificationController.add(frame);
      }
    });
  }

  final BleConfig _config;
  final MCUCore _mcu;
  StreamSubscription<Uint8List>? _outboundSub;

  final _adapterController =
      StreamController<BleAdapterState>.broadcast(sync: true);
  final _scanController =
      StreamController<List<BleDevice>>.broadcast(sync: true);
  final _connectionController = StreamController<bool>.broadcast(sync: true);
  final _notificationController =
      StreamController<Uint8List>.broadcast(sync: true);
  final _rssiController = StreamController<int>.broadcast(sync: true);

  bool _connected = false;
  BleDevice? _device;
  int _mtu = 23;

  /// Access the simulated MCU for tests / diagnostics.
  MCUCore get mcu => _mcu;

  BleDevice get _advertisedDevice => BleDevice(
        id: 'virtual-${_mcu.state.mcuId}',
        name: '${_config.deviceNamePrefix}-VIRTUAL-01',
        rssi: _mcu.state.rssi,
        advertisementName: '${_config.deviceNamePrefix}-VIRTUAL-01',
      );

  @override
  Stream<BleAdapterState> get adapterStateStream => _adapterController.stream;

  @override
  Stream<List<BleDevice>> get scanResultsStream => _scanController.stream;

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  Stream<Uint8List> get notificationStream => _notificationController.stream;

  @override
  Stream<int> get rssiStream => _rssiController.stream;

  @override
  bool get isConnected => _connected;

  @override
  BleDevice? get connectedDevice => _device;

  @override
  Future<void> ensurePermissions() async {}

  @override
  Future<BleAdapterState> adapterState() async {
    _adapterController.add(BleAdapterState.on);
    return BleAdapterState.on;
  }

  @override
  Future<List<BleDevice>> startScan({
    required Duration timeout,
    String? namePrefix,
  }) async {
    await adapterState();
    final prefix = namePrefix ?? _config.deviceNamePrefix;
    final device = _advertisedDevice;
    final list = <BleDevice>[
      if (device.name.startsWith(prefix) || prefix.isEmpty) device,
    ];
    _scanController.add(list);
    return list;
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(BleDevice device, {required Duration timeout}) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    _device = device;
    _connected = true;
    _mcu.connectBle();
    _connectionController.add(true);
    _rssiController.add(_mcu.state.rssi);
  }

  @override
  Future<void> disconnect() async {
    _mcu.disconnectBle();
    _connected = false;
    _device = null;
    _connectionController.add(false);
  }

  @override
  Future<int> requestMtu(int mtu) async {
    _mtu = mtu.clamp(23, 512);
    return _mtu;
  }

  @override
  Future<void> discoverServices() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> write(Uint8List bytes, {bool withoutResponse = false}) async {
    if (!_connected) {
      throw StateError('VirtualMCUTransport: not connected');
    }
    final response = await _mcu.handleWrite(bytes);
    if (response != null) {
      _notificationController.add(response);
    }
  }

  @override
  Future<Uint8List?> read() async => null;

  @override
  Future<int?> readRssi() async {
    _rssiController.add(_mcu.state.rssi);
    return _mcu.state.rssi;
  }

  @override
  Future<void> dispose() async {
    await _outboundSub?.cancel();
    await disconnect();
    await _mcu.dispose();
    await _adapterController.close();
    await _scanController.close();
    await _connectionController.close();
    await _notificationController.close();
    await _rssiController.close();
  }
}
