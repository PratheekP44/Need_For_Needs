import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/ble.dart';
import 'package:virtual_mcu/virtual_mcu.dart';

void main() {
  test('LockerService ↔ VirtualMCUTransport end-to-end', () async {
    final transport = VirtualMCUTransport(
      config: BleConfig.development(),
      simulation: const SimulationConfig(
        openDelay: Duration(milliseconds: 30),
      ),
    );
    final service = LockerService(
      config: BleConfig.development(),
      transport: transport,
    );
    addTearDown(service.dispose);

    final devices = await service.scanForLockers();
    expect(devices, isNotEmpty);
    await service.connect(devices.first, lockerId: 'LCK-A1');

    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600;
    const boxId = 'BOX-03';
    final token = 'CE1.ORD-VM.LCK-A1.$boxId.$exp.aabbccdd';

    final auth = await service.authenticateCollection(
      orderId: 'ORD-VM',
      lockerId: 'LCK-A1',
      boxId: boxId,
      collectionToken: token,
    );
    expect(auth.success, isTrue);

    final open = await service.openBox(
      orderId: 'ORD-VM',
      lockerId: 'LCK-A1',
      boxId: boxId,
      collectionToken: token,
    );
    expect(open.success, isTrue);
    expect(service.state, LockerState.success);
    expect(transport.mcu.matrix.find(boxId)!.doorState, DoorState.open);
    expect(transport.mcu.logger.entries, isNotEmpty);
  });

  test('development config selects Virtual MCU by default', () {
    final service = LockerService(config: BleConfig.development());
    addTearDown(service.dispose);
    expect(service.config.useVirtualMcuTransport, isTrue);
  });
}
