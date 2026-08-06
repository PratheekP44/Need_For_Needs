import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/ble_config.dart';
import '../locker/locker_service.dart';
import '../models/ble_device.dart';
import '../models/locker_connection.dart';
import '../models/locker_state.dart';
import '../models/packet.dart';
import '../transport/ble_transport.dart';

/// Transport selection: Virtual MCU (dev) vs Real BLE (CC2340).
enum BleTransportMode {
  virtualMcu,
  realBle,
}

/// Holds the active [BleConfig]; switching recreates [lockerServiceProvider].
class BleConfigNotifier extends Notifier<BleConfig> {
  @override
  BleConfig build() => BleConfig.development();

  BleTransportMode get mode => state.isRealBle
      ? BleTransportMode.realBle
      : BleTransportMode.virtualMcu;

  void useVirtualMcu() {
    state = BleConfig.development();
  }

  void useRealBle() {
    state = BleConfig.hardware();
  }

  void setMode(BleTransportMode mode) {
    switch (mode) {
      case BleTransportMode.virtualMcu:
        useVirtualMcu();
      case BleTransportMode.realBle:
        useRealBle();
    }
  }
}

final bleConfigProvider =
    NotifierProvider<BleConfigNotifier, BleConfig>(BleConfigNotifier.new);

/// Business façade — UI should depend on this, not transport/protocol.
final lockerServiceProvider = Provider<LockerService>((ref) {
  final config = ref.watch(bleConfigProvider);
  final service = LockerService(config: config);
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

/// Bluetooth adapter state stream.
final bluetoothStateProvider = StreamProvider<BleAdapterState>((ref) {
  final service = ref.watch(lockerServiceProvider);
  unawaited(service.refreshAdapterState());
  return service.adapterStateStream;
});

/// Locker session state machine stream.
final connectionStateProvider = StreamProvider<LockerState>((ref) {
  final service = ref.watch(lockerServiceProvider);
  return Stream<LockerState>.multi((controller) {
    controller.add(service.state);
    final sub = service.stateStream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = sub.cancel;
  });
});

/// Nearby discovered lockers.
final nearbyLockersProvider = StreamProvider<List<BleDevice>>((ref) {
  final service = ref.watch(lockerServiceProvider);
  return Stream<List<BleDevice>>.multi((controller) {
    controller.add(service.nearbyLockers);
    final sub = service.nearbyLockersStream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = sub.cancel;
  });
});

/// Current locker connection snapshot.
final currentLockerProvider = StreamProvider<LockerConnection>((ref) {
  final service = ref.watch(lockerServiceProvider);
  return Stream<LockerConnection>.multi((controller) {
    controller.add(service.currentConnection);
    final sub = service.connectionStream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = sub.cancel;
  });
});

/// Last locker STATUS_RESPONSE map.
final lockerStatusProvider = StreamProvider<Map<String, Object?>>((ref) {
  final service = ref.watch(lockerServiceProvider);
  return Stream<Map<String, Object?>>.multi((controller) {
    controller.add(service.lockerStatus);
    final sub = service.lockerStatusStream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = sub.cancel;
  });
});

/// Door status string (`OPEN` / `CLOSED` / …).
final doorStatusProvider = StreamProvider<String>((ref) {
  final service = ref.watch(lockerServiceProvider);
  return Stream<String>.multi((controller) {
    controller.add(service.doorStatus);
    final sub = service.doorStatusStream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = sub.cancel;
  });
});

/// Decoded packet stream from [BleProtocol].
final packetStreamProvider = StreamProvider<Packet>((ref) {
  final service = ref.watch(lockerServiceProvider);
  return service.packetStream.cast<Packet>();
});
