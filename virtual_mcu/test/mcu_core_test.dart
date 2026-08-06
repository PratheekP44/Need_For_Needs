import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:virtual_mcu/virtual_mcu.dart';

void main() {
  late MCUCore mcu;
  const codec = FrameCodec();

  setUp(() {
    mcu = MCUCore(
      config: const SimulationConfig(
        openDelay: Duration(milliseconds: 20),
      ),
    );
    mcu.connectBle();
  });

  tearDown(() async {
    await mcu.dispose();
  });

  String token({String box = 'BOX-03'}) {
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600;
    return 'CE1.ORD-1.LCK-A1.$box.$exp.deadbeef';
  }

  Uint8List authFrame({String box = 'BOX-03', int seq = 1}) {
    return codec.encode(
      type: McuPacketType.auth,
      sequenceNumber: seq,
      orderId: 'ORD-1',
      lockerId: 'LCK-A1',
      boxId: box,
      collectionToken: token(box: box),
      payload: codec.jsonPayload({'phoneNonce': 'n1'}),
    );
  }

  test('matrix defaults to 4x4 with 16 boxes', () {
    expect(mcu.matrix.boxes.length, 16);
    expect(mcu.matrix.find('BOX-03'), isNotNull);
  });

  test('AUTH then OPEN_BOX succeeds', () async {
    final auth = await mcu.handleWrite(authFrame());
    expect(auth, isNotNull);
    final authDecoded = codec.decode(auth!);
    expect(authDecoded.type, McuPacketType.authAck);

    final open = await mcu.handleWrite(
      codec.encode(
        type: McuPacketType.openBox,
        sequenceNumber: 2,
        orderId: 'ORD-1',
        lockerId: 'LCK-A1',
        boxId: 'BOX-03',
        collectionToken: token(),
        payload: codec.jsonPayload({'reason': 'collection'}),
      ),
    );
    expect(open, isNotNull);
    final openDecoded = codec.decode(open!);
    expect(openDecoded.type, McuPacketType.openAck);
    expect(openDecoded.payloadJson()?['opened'], isTrue);
    expect(mcu.matrix.find('BOX-03')!.doorState, DoorState.open);
  });

  test('invalid token rejected', () async {
    final frame = codec.encode(
      type: McuPacketType.auth,
      sequenceNumber: 1,
      lockerId: 'LCK-A1',
      boxId: 'BOX-03',
      collectionToken: 'bad-token',
    );
    final res = await mcu.handleWrite(frame);
    final decoded = codec.decode(res!);
    expect(decoded.type, McuPacketType.error);
    expect(decoded.payloadJson()?['name'], 'INVALID_TOKEN');
  });

  test('busy locker returns LOCKER_BUSY', () async {
    final busy = MCUCore(
      config: const SimulationConfig(
        forceBusy: true,
        openDelay: Duration(milliseconds: 10),
      ),
    );
    addTearDown(busy.dispose);
    busy.connectBle();
    await busy.handleWrite(authFrame(seq: 1));
    final open = await busy.handleWrite(
      codec.encode(
        type: McuPacketType.openBox,
        sequenceNumber: 2,
        orderId: 'ORD-1',
        lockerId: 'LCK-A1',
        boxId: 'BOX-03',
        collectionToken: token(),
      ),
    );
    expect(codec.decode(open!).payloadJson()?['name'], 'LOCKER_BUSY');
  });

  test('door jam simulation', () async {
    final jam = MCUCore(
      config: const SimulationConfig(
        forceDoorJam: true,
        openDelay: Duration(milliseconds: 10),
      ),
    );
    addTearDown(jam.dispose);
    jam.connectBle();
    await jam.handleWrite(authFrame(seq: 1));
    final open = await jam.handleWrite(
      codec.encode(
        type: McuPacketType.openBox,
        sequenceNumber: 2,
        orderId: 'ORD-1',
        lockerId: 'LCK-A1',
        boxId: 'BOX-03',
        collectionToken: token(),
      ),
    );
    expect(codec.decode(open!).payloadJson()?['name'], 'DOOR_JAM');
  });

  test('runtime log table populated', () async {
    await mcu.handleWrite(authFrame());
    expect(mcu.logger.entries, isNotEmpty);
    expect(mcu.logger.toTable().first.keys, contains('timestamp'));
    expect(mcu.debugSnapshot()['runtime'], isA<Map>());
  });

  test('reset MCU clears session', () {
    mcu.state.authenticated = true;
    mcu.resetMcu();
    expect(mcu.state.authenticated, isFalse);
    expect(mcu.state.packetCounter, 0);
  });
}
