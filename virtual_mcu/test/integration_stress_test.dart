import 'package:test/test.dart';
import 'package:virtual_mcu/virtual_mcu.dart';

void main() {
  const codec = FrameCodec();

  test('100 packet exchanges (PING/PONG)', () async {
    final mcu = MCUCore(
      config: const SimulationConfig(openDelay: Duration(milliseconds: 1)),
    );
    addTearDown(mcu.dispose);
    mcu.connectBle();

    for (var i = 1; i <= 100; i++) {
      final req = codec.encode(
        type: McuPacketType.ping,
        sequenceNumber: i,
        lockerId: 'LCK-A1',
      );
      final res = await mcu.handleWrite(req);
      expect(res, isNotNull, reason: 'missing pong at $i');
      expect(codec.decode(res!).type, McuPacketType.pong);
    }
    expect(mcu.state.packetCounter, greaterThanOrEqualTo(100));
  });

  test('multiple AUTH requests', () async {
    final mcu = MCUCore();
    addTearDown(mcu.dispose);
    mcu.connectBle();
    for (var i = 1; i <= 5; i++) {
      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600;
      final token = 'CE1.ORD-$i.LCK-A1.BOX-0$i.$exp.n$i';
      final res = await mcu.handleWrite(
        codec.encode(
          type: McuPacketType.auth,
          sequenceNumber: i,
          orderId: 'ORD-$i',
          lockerId: 'LCK-A1',
          boxId: 'BOX-0$i',
          collectionToken: token,
        ),
      );
      expect(codec.decode(res!).type, McuPacketType.authAck);
    }
  });

  test('packet loss yields null response', () async {
    final mcu = MCUCore(
      config: const SimulationConfig(packetLossRate: 1.0),
    );
    addTearDown(mcu.dispose);
    mcu.connectBle();
    final res = await mcu.handleWrite(
      codec.encode(type: McuPacketType.ping, sequenceNumber: 1),
    );
    expect(res, isNull);
  });

  test('BLE timeout simulation yields null', () async {
    final mcu = MCUCore(
      config: const SimulationConfig(forceBleTimeout: true),
    );
    addTearDown(mcu.dispose);
    mcu.connectBle();
    final res = await mcu.handleWrite(
      codec.encode(type: McuPacketType.ping, sequenceNumber: 1),
    );
    expect(res, isNull);
  });

  test('multiple OPEN after AUTH', () async {
    final mcu = MCUCore(
      config: const SimulationConfig(openDelay: Duration(milliseconds: 5)),
    );
    addTearDown(mcu.dispose);
    mcu.connectBle();

    Future<void> openBox(String boxId, int seqBase) async {
      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600;
      final token = 'CE1.ORD-1.LCK-A1.$boxId.$exp.x';
      await mcu.handleWrite(
        codec.encode(
          type: McuPacketType.auth,
          sequenceNumber: seqBase,
          orderId: 'ORD-1',
          lockerId: 'LCK-A1',
          boxId: boxId,
          collectionToken: token,
        ),
      );
      // Close previous door if open so DOOR_ALREADY_OPEN does not trip.
      final box = mcu.matrix.find(boxId)!;
      if (box.doorState == DoorState.open) {
        await mcu.doors.close(box);
      }
      final open = await mcu.handleWrite(
        codec.encode(
          type: McuPacketType.openBox,
          sequenceNumber: seqBase + 1,
          orderId: 'ORD-1',
          lockerId: 'LCK-A1',
          boxId: boxId,
          collectionToken: token,
        ),
      );
      expect(codec.decode(open!).type, McuPacketType.openAck);
    }

    await openBox('BOX-01', 1);
    await openBox('BOX-02', 10);
    await openBox('BOX-03', 20);
  });
}
