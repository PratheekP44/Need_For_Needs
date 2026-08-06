import 'dart:async';

import 'package:virtual_mcu/virtual_mcu.dart';

import '../config/ble_config.dart';
import '../managers/connection_manager.dart';
import '../models/ble_device.dart';
import '../models/locker_connection.dart';
import '../models/locker_state.dart';
import '../models/packet_result.dart';
import '../protocol/ble_protocol.dart';
import '../protocol/packet_types.dart';
import '../transport/ble_transport.dart';
import '../transport/flutter_blue_transport.dart';
import '../transport/mock_ble_transport.dart';
import '../transport/virtual_mcu_transport.dart';

/// Collection / locker business façade.
///
/// UI calls only this layer — never builds packets or touches GATT directly.
class LockerService {
  LockerService({
    required BleConfig config,
    BleTransport? transport,
  }) : _config = config {
    _transport = transport ?? _defaultTransport(config);
    _connection = ConnectionManager(
      transport: _transport,
      config: config,
      onReconnecting: () => _setState(LockerState.reconnecting),
      onReconnected: () {
        _protocol.attachNotifications();
        _setState(LockerState.connected);
      },
    );
    _protocol = BleProtocol(connection: _connection);
  }

  static BleTransport _defaultTransport(BleConfig config) {
    if (config.useVirtualMcuTransport) {
      return VirtualMCUTransport(config: config);
    }
    if (config.useMockTransport) {
      return MockBleTransport(config: config);
    }
    return FlutterBlueTransport(config: config);
  }

  final BleConfig _config;
  late final BleTransport _transport;
  late final ConnectionManager _connection;
  late final BleProtocol _protocol;

  final _stateController = StreamController<LockerState>.broadcast(sync: true);
  final _connectionSnapshot =
      StreamController<LockerConnection>.broadcast(sync: true);
  final _nearbyController =
      StreamController<List<BleDevice>>.broadcast(sync: true);
  final _lockerStatusController =
      StreamController<Map<String, Object?>>.broadcast(sync: true);
  final _doorStatusController = StreamController<String>.broadcast(sync: true);

  LockerState _state = LockerState.disconnected;
  LockerConnection _snapshot = LockerConnection.empty();
  List<BleDevice> _nearby = const [];
  Map<String, Object?> _lockerStatus = const {};
  String _doorStatus = 'UNKNOWN';

  Stream<LockerState> get stateStream => _stateController.stream;
  Stream<LockerConnection> get connectionStream =>
      _connectionSnapshot.stream;
  Stream<List<BleDevice>> get nearbyLockersStream => _nearbyController.stream;
  Stream<Map<String, Object?>> get lockerStatusStream =>
      _lockerStatusController.stream;
  Stream<String> get doorStatusStream => _doorStatusController.stream;
  Stream get packetStream => _protocol.packetStream;
  Stream<BleAdapterState> get adapterStateStream =>
      _transport.adapterStateStream;

  LockerState get state => _state;
  LockerConnection get currentConnection => _snapshot;
  List<BleDevice> get nearbyLockers => _nearby;
  Map<String, Object?> get lockerStatus => _lockerStatus;
  String get doorStatus => _doorStatus;
  BleConfig get config => _config;
  BleProtocol get protocol => _protocol;
  BleTransport get transport => _transport;

  /// Shared Virtual MCU when [VirtualMCUTransport] is active; otherwise null.
  MCUCore? get virtualMcu {
    final t = _transport;
    if (t is VirtualMCUTransport) return t.mcu;
    return null;
  }

  void _setState(LockerState next, {String? error}) {
    _state = next;
    _snapshot = _snapshot.copyWith(state: next, lastError: error);
    _stateController.add(next);
    _connectionSnapshot.add(_snapshot);
  }

  Future<BleAdapterState> refreshAdapterState() => _transport.adapterState();

  /// Scan for nearby Campus Essentials lockers.
  Future<List<BleDevice>> scanForLockers() async {
    _setState(LockerState.scanning);
    try {
      await _connection.ensurePermissions();
      final devices = await _connection.scan();
      _nearby = devices;
      _nearbyController.add(devices);
      _setState(LockerState.disconnected);
      return devices;
    } catch (error) {
      _setState(LockerState.failure, error: error.toString());
      rethrow;
    }
  }

  /// Connect to a discovered device (multi-locker ready).
  Future<void> connect(BleDevice device, {String? lockerId}) async {
    _setState(LockerState.connecting);
    try {
      await _connection.connect(device);
      _protocol.attachNotifications();
      final mtu = switch (_transport) {
        final FlutterBlueTransport fbp => fbp.lastMtu ?? _config.desiredMtu,
        _ => _config.desiredMtu,
      };
      _snapshot = LockerConnection(
        device: device,
        state: LockerState.connected,
        lockerId: lockerId,
        mtu: mtu,
      );
      _setState(LockerState.connected);
    } catch (error) {
      _setState(LockerState.failure, error: error.toString());
      rethrow;
    }
  }

  /// Validate collection token format (expiry) then AUTH with locker.
  ///
  /// Cryptographic verification remains a later phase on firmware/server.
  Future<PacketResult> authenticateCollection({
    required String orderId,
    required String lockerId,
    required String boxId,
    required String collectionToken,
  }) async {
    _validateTokenFormat(collectionToken);
    _snapshot = _snapshot.copyWith(
      orderId: orderId,
      lockerId: lockerId,
      boxId: boxId,
    );
    _setState(LockerState.authenticating);
    _setState(LockerState.waitingResponse);

    final result = await _protocol.authenticate(
      orderId: orderId,
      lockerId: lockerId,
      boxId: boxId,
      collectionToken: collectionToken,
    );

    if (!result.success) {
      _setState(
        LockerState.failure,
        error: result.message ?? result.errorCode?.wireName,
      );
      return result;
    }

    final accepted = result.responsePayload?['accepted'] == true;
    if (!accepted) {
      _setState(LockerState.failure, error: 'AUTH rejected');
      return PacketResult.failure(
        request: result.request,
        response: result.response,
        errorCode: BleErrorCode.invalidToken,
        message: 'AUTH_ACK accepted=false',
      );
    }

    _snapshot = _snapshot.copyWith(authenticated: true);
    _setState(LockerState.authenticated);
    return result;
  }

  /// Open a specific box after authentication.
  Future<PacketResult> openBox({
    required String orderId,
    required String lockerId,
    required String boxId,
    required String collectionToken,
  }) async {
    if (!_snapshot.authenticated && _state != LockerState.authenticated) {
      return PacketResult.failure(
        message: 'Must authenticate before opening box (state=$_state)',
      );
    }

    _setState(LockerState.opening);
    _setState(LockerState.waitingResponse);

    final result = await _protocol.openBox(
      orderId: orderId,
      lockerId: lockerId,
      boxId: boxId,
      collectionToken: collectionToken,
    );

    if (!result.success) {
      _setState(
        LockerState.failure,
        error: result.message ?? result.errorCode?.wireName,
      );
      return result;
    }

    final opened = result.responsePayload?['opened'] == true;
    final door = result.responsePayload?['doorState']?.toString() ?? 'UNKNOWN';
    _doorStatus = door;
    _doorStatusController.add(door);

    if (!opened) {
      _setState(LockerState.failure, error: 'OPEN_ACK opened=false');
      return PacketResult.failure(
        request: result.request,
        response: result.response,
        message: 'Door did not open',
      );
    }

    _setState(LockerState.success);
    return result;
  }

  /// Request locker/box status and update streams.
  Future<PacketResult> requestLockerStatus({
    required String lockerId,
    String boxId = '',
  }) async {
    _setState(LockerState.waitingResponse);
    final result = await _protocol.requestStatus(
      lockerId: lockerId,
      boxId: boxId,
    );
    if (result.success) {
      _lockerStatus = Map<String, Object?>.from(
        result.responsePayload ?? const {},
      );
      _lockerStatusController.add(_lockerStatus);
      final door = _lockerStatus['doorState']?.toString();
      if (door != null) {
        _doorStatus = door;
        _doorStatusController.add(door);
      }
      if (_snapshot.authenticated) {
        _setState(LockerState.authenticated);
      } else if (_connection.isConnected) {
        _setState(LockerState.connected);
      } else {
        _setState(LockerState.disconnected);
      }
    } else {
      _setState(
        LockerState.failure,
        error: result.message ?? result.errorCode?.wireName,
      );
    }
    return result;
  }

  Future<String> getDoorStatus({
    required String lockerId,
    String boxId = '',
  }) async {
    final result = await requestLockerStatus(lockerId: lockerId, boxId: boxId);
    if (!result.success) {
      throw StateError(result.message ?? 'Failed to read door status');
    }
    return _doorStatus;
  }

  /// End session safely (DISCONNECT packet best-effort + link drop).
  Future<void> disconnectSafely() async {
    try {
      if (_connection.isConnected) {
        await _protocol.sendDisconnect(
          lockerId: _snapshot.lockerId ?? '',
        );
      }
    } catch (_) {
      // Best effort.
    }
    await _connection.disconnect();
    _snapshot = LockerConnection.empty();
    _setState(LockerState.disconnected);
  }

  /// Convenience: scan → connect first match → auth → open.
  Future<PacketResult> collectFromLocker({
    required String orderId,
    required String lockerId,
    required String boxId,
    required String collectionToken,
    BleDevice? device,
  }) async {
    final target = device ??
        (_nearby.isNotEmpty
            ? _nearby.first
            : (await scanForLockers()).firstOrNull);
    if (target == null) {
      _setState(LockerState.failure, error: 'No locker found');
      return PacketResult.failure(message: 'No locker found');
    }

    await connect(target, lockerId: lockerId);
    final auth = await authenticateCollection(
      orderId: orderId,
      lockerId: lockerId,
      boxId: boxId,
      collectionToken: collectionToken,
    );
    if (!auth.success) return auth;

    return openBox(
      orderId: orderId,
      lockerId: lockerId,
      boxId: boxId,
      collectionToken: collectionToken,
    );
  }

  void _validateTokenFormat(String token) {
    final parts = token.split('.');
    if (parts.length != 6 || parts.first != 'CE1') {
      throw FormatException('INVALID_TOKEN: malformed collectionToken');
    }
    final exp = int.tryParse(parts[4]);
    if (exp == null) {
      throw FormatException('INVALID_TOKEN: bad expiry');
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now > exp + 30) {
      throw FormatException('INVALID_TOKEN: token expired');
    }
  }

  Future<void> dispose() async {
    await disconnectSafely();
    await _protocol.dispose();
    await _connection.dispose();
    await _stateController.close();
    await _connectionSnapshot.close();
    await _nearbyController.close();
    await _lockerStatusController.close();
    await _doorStatusController.close();
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
