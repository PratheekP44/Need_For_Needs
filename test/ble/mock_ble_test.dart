import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/ble.dart';

void main() {
  late LockerService service;

  setUp(() {
    service = LockerService(config: BleConfig.development());
  });

  tearDown(() async {
    await service.dispose();
  });

  test('mock scan → connect → auth → open happy path', () async {
    final devices = await service.scanForLockers();
    expect(devices, isNotEmpty);
    expect(service.state, LockerState.disconnected);

    await service.connect(devices.first, lockerId: 'LCK-A1');
    expect(service.state, LockerState.connected);

    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600;
    final token = 'CE1.ORD-1.LCK-A1.BOX-03.$exp.deadbeef';

    final auth = await service.authenticateCollection(
      orderId: 'ORD-1',
      lockerId: 'LCK-A1',
      boxId: 'BOX-03',
      collectionToken: token,
    );
    expect(auth.success, isTrue);
    expect(service.state, LockerState.authenticated);

    final open = await service.openBox(
      orderId: 'ORD-1',
      lockerId: 'LCK-A1',
      boxId: 'BOX-03',
      collectionToken: token,
    );
    expect(open.success, isTrue);
    expect(service.state, LockerState.success);
    expect(service.doorStatus, 'OPEN');

    final status = await service.requestLockerStatus(
      lockerId: 'LCK-A1',
      boxId: 'BOX-03',
    );
    expect(status.success, isTrue);
    expect(service.lockerStatus['doorState'], isNotNull);

    await service.disconnectSafely();
    expect(service.state, LockerState.disconnected);
  });

  test('mock auth failure ends in Failure state', () async {
    final failing = LockerService(
      config: BleConfig.development(),
      transport: MockBleTransport(failAuth: true),
    );
    addTearDown(failing.dispose);

    final devices = await failing.scanForLockers();
    await failing.connect(devices.first);
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600;
    final result = await failing.authenticateCollection(
      orderId: 'ORD-1',
      lockerId: 'LCK-A1',
      boxId: 'BOX-03',
      collectionToken: 'CE1.ORD-1.LCK-A1.BOX-03.$exp.deadbeef',
    );
    expect(result.success, isFalse);
    expect(failing.state, LockerState.failure);
  });

  test('expired token rejected before AUTH', () async {
    final devices = await service.scanForLockers();
    await service.connect(devices.first);
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 120;
    expect(
      () => service.authenticateCollection(
        orderId: 'ORD-1',
        lockerId: 'LCK-A1',
        boxId: 'BOX-03',
        collectionToken: 'CE1.ORD-1.LCK-A1.BOX-03.$exp.old',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
