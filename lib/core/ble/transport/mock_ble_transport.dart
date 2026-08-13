import 'dart:async';
import 'dart:typed_data';

import '../config/ble_config.dart';
import '../models/ble_device.dart';
import '../models/packet.dart';
import '../models/packet_payload.dart';
import '../protocol/packet_codec.dart';
import '../protocol/packet_types.dart';
import 'ble_transport.dart';

/// In-memory transport that simulates a TI CC2340 locker for UI development.
class MockBleTransport implements BleTransport {
  MockBleTransport({
    BleConfig? config,
    this.simulateTimeouts = false,
    this.failAuth = false,
    this.failOpen = false,
    this.openDelay = const Duration(milliseconds: 120),
  }) : _config = config ?? BleConfig.development();

  final BleConfig _config;
  final bool simulateTimeouts;
  final bool failAuth;
  final bool failOpen;
  final Duration openDelay;
  final PacketCodec _codec = const PacketCodec();

  final _adapterController =
      StreamController<BleAdapterState>.broadcast();
  final _scanController = StreamController<List<BleDevice>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _notificationController = StreamController<Uint8List>.broadcast();
  final _rssiController = StreamController<int>.broadcast();

  bool _connected = false;
  BleDevice? _device;
  int _mtu = 23;
  Timer? _scanTimer;

  static const _mockDevice = BleDevice(
    id: 'mock-ce-locker-001',
    name: 'CE-LOCKER-MOCK-01',
    rssi: -55,
    advertisementName: 'CE-LOCKER-MOCK-01',
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
    bool stopOnTarget = false,
  }) async {
    await adapterState();
    final prefix = namePrefix ?? _config.deviceNamePrefix;
    final devices = <BleDevice>[
      if (_mockDevice.name.startsWith(prefix) || prefix.isEmpty) _mockDevice,
    ];
    _scanController.add(devices);
    _scanTimer?.cancel();
    if (stopOnTarget && devices.any((d) => d.isTargetLocker)) {
      return devices;
    }
    _scanTimer = Timer(timeout, () {});
    return devices;
  }

  @override
  Future<void> stopScan() async {
    _scanTimer?.cancel();
  }

  @override
  Future<void> connect(BleDevice device, {required Duration timeout}) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _device = device;
    _connected = true;
    _connectionController.add(true);
    _rssiController.add(device.rssi ?? -60);
  }

  @override
  Future<void> disconnect() async {
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
      throw StateError('MockBleTransport: not connected');
    }
    if (simulateTimeouts) {
      // Swallow — caller times out.
      return;
    }

    final request = _codec.decode(bytes);
    await Future<void>.delayed(openDelay);

    final response = _buildResponse(request);
    if (response != null) {
      final frame = _codec.encode(response);
      _notificationController.add(frame);
    }
  }

  Packet? _buildResponse(Packet request) {
    final seq = request.header.sequenceNumber;
    final lockerId = request.header.lockerId;
    final boxId = request.header.boxId;
    final orderId = request.header.orderId;

    switch (request.packetType) {
      case BlePacketType.ping:
        return Packet.build(
          type: BlePacketType.pong,
          sequenceNumber: seq,
          lockerId: lockerId,
        );
      case BlePacketType.auth:
        if (failAuth) {
          return Packet.build(
            type: BlePacketType.error,
            sequenceNumber: seq,
            orderId: orderId,
            lockerId: lockerId,
            boxId: boxId,
            payload: PacketPayload.error(
              code: BleErrorCode.invalidToken,
              message: 'mock auth failure',
            ),
          );
        }
        return Packet.build(
          type: BlePacketType.authAck,
          sequenceNumber: seq,
          orderId: orderId,
          lockerId: lockerId,
          boxId: boxId,
          payload: PacketPayload.authAck(
            accepted: true,
            firmwareVersion: 'mock-0.0.1',
          ),
        );
      case BlePacketType.openBox:
        if (failOpen) {
          return Packet.build(
            type: BlePacketType.error,
            sequenceNumber: seq,
            orderId: orderId,
            lockerId: lockerId,
            boxId: boxId,
            payload: PacketPayload.error(
              code: BleErrorCode.lockerBusy,
              message: 'mock open failure',
            ),
          );
        }
        return Packet.build(
          type: BlePacketType.openAck,
          sequenceNumber: seq,
          orderId: orderId,
          lockerId: lockerId,
          boxId: boxId,
          payload: PacketPayload.openAck(
            opened: true,
            doorState: 'OPEN',
            boxStatus: 'AVAILABLE',
          ),
        );
      case BlePacketType.status:
        return Packet.build(
          type: BlePacketType.statusResponse,
          sequenceNumber: seq,
          lockerId: lockerId,
          boxId: boxId,
          payload: PacketPayload.statusResponse(
            doorState: 'CLOSED',
            boxStatus: 'AVAILABLE',
            batteryMv: 3300,
            uptimeSeconds: 1000,
          ),
        );
      case BlePacketType.heartbeat:
        return Packet.build(
          type: BlePacketType.heartbeat,
          sequenceNumber: seq,
          lockerId: lockerId,
          payload: PacketPayload.heartbeat(rssi: -58),
        );
      case BlePacketType.disconnect:
        scheduleMicrotask(() async {
          await disconnect();
        });
        return null;
      default:
        return Packet.build(
          type: BlePacketType.error,
          sequenceNumber: seq,
          payload: PacketPayload.error(
            code: BleErrorCode.unknownCommand,
            message: 'unexpected ${request.packetType.wireName}',
          ),
        );
    }
  }

  @override
  Future<Uint8List?> read() async => null;

  @override
  Future<int?> readRssi() async => _device?.rssi ?? -60;

  @override
  Future<void> dispose() async {
    _scanTimer?.cancel();
    await disconnect();
    await _adapterController.close();
    await _scanController.close();
    await _connectionController.close();
    await _notificationController.close();
    await _rssiController.close();
  }
}
