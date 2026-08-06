import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/ble.dart';

/// Phase 13A: scan → connect → discover → notify (no AUTH / packets).
void main() {
  test('Phase 13A Virtual MCU: scan, connect, ready without auth', () async {
    final config = BleConfig.development();
    final service = LockerService(config: config);
    addTearDown(service.dispose);

    final devices = await service.scanForLockers();
    expect(devices, isNotEmpty);
    expect(devices.first.name, contains('CE-LOCKER'));
    expect(devices.first.rssi, isNotNull);

    await service.connect(devices.first);
    expect(service.state, LockerState.connected);
    expect(service.transport.isConnected, isTrue);

    // Pipeline completed notifications attach — no AUTH called.
    expect(service.currentConnection.authenticated, isFalse);

    await service.disconnectSafely();
    expect(service.state, LockerState.disconnected);
  });

  test('hardware config targets CC2340 Service UUID filter', () {
    final config = BleConfig.hardware();
    expect(config.isRealBle, isTrue);
    expect(config.serviceUuid.str.toLowerCase(), BleConfig.cc2340ServiceUuid);
    expect(
      config.writeCharacteristicUuid.str.toLowerCase(),
      BleConfig.cc2340CommandCharacteristicUuid,
    );
    expect(
      config.notifyCharacteristicUuid.str.toLowerCase(),
      BleConfig.cc2340StatusCharacteristicUuid,
    );
    expect(config.deviceNamePrefix, isEmpty);
  });
}
