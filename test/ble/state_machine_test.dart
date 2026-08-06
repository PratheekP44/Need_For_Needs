import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/ble.dart';

void main() {
  test('LockerState terminal flags', () {
    expect(LockerState.success.isTerminal, isTrue);
    expect(LockerState.failure.isTerminal, isTrue);
    expect(LockerState.connected.isTerminal, isFalse);
    expect(LockerState.authenticated.isConnectedish, isTrue);
    expect(LockerState.disconnected.isConnectedish, isFalse);
  });

  test('service state progresses through expected values', () async {
    final service = LockerService(config: BleConfig.development());
    addTearDown(service.dispose);

    final seen = <LockerState>[];
    final sub = service.stateStream.listen(seen.add);

    final devices = await service.scanForLockers();
    await service.connect(devices.first);
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600;
    final token = 'CE1.ORD-1.LCK-A1.BOX-03.$exp.n1';
    await service.authenticateCollection(
      orderId: 'ORD-1',
      lockerId: 'LCK-A1',
      boxId: 'BOX-03',
      collectionToken: token,
    );
    final open = await service.openBox(
      orderId: 'ORD-1',
      lockerId: 'LCK-A1',
      boxId: 'BOX-03',
      collectionToken: token,
    );
    expect(open.success, isTrue, reason: open.message);
    expect(service.state, LockerState.success);

    await sub.cancel();

    expect(seen, contains(LockerState.scanning));
    expect(seen, contains(LockerState.connecting));
    expect(seen, contains(LockerState.connected));
    expect(seen, contains(LockerState.authenticating));
    expect(seen, contains(LockerState.authenticated));
    expect(seen, contains(LockerState.opening));
    expect(seen, contains(LockerState.success));
    expect(service.state, LockerState.success);
  });
}
