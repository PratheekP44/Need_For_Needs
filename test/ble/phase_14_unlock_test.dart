import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/ble.dart';

void main() {
  group('PacketBuilder', () {
    test('builds AUTH and OPEN with port in JSON payload', () {
      final builder = PacketBuilder();
      const request = UnlockPacketRequest(
        transactionId: 'tx-1',
        orderId: 'ORD-DEMO-1',
        lockerId: 'LCK-A1',
        boxId: 'BOX-03',
        port: 3,
        collectionToken: 'CE1.ORD-DEMO-1.LCK-A1.BOX-03.1893456000.deadbeef',
        bluetoothAddress: 'AA:BB:CC:DD:EE:FF',
        advertisementId: 'adv-1',
        frameCounter: 7,
        timestamp: 1722691200,
      );

      final auth = builder.buildAuth(request);
      expect(auth, isA<Uint8List>());
      expect(auth.length, greaterThan(20));

      // Header bytes 2–3 remain sequenceNumber (7), not port.
      expect(auth[2], 0x00);
      expect(auth[3], 0x07);

      final open = builder.buildUnlock(request);
      expect(open, isA<Uint8List>());
      expect(open.length, greaterThan(20));
      expect(open[2], 0x00);
      expect(open[3], 0x07);

      final codec = const PacketCodec();
      final authPkt = codec.decode(auth);
      expect(authPkt.packetType, BlePacketType.auth);
      expect(authPkt.header.sequenceNumber, 7);
      expect(authPkt.header.lockerId, 'LCK-A1');
      expect(authPkt.payload.asJsonMap()?['transactionId'], 'tx-1');
      expect(authPkt.payload.asJsonMap()?['port'], 3);
      expect(authPkt.payload.asJsonMap()?['bluetoothAddress'], 'AA:BB:CC:DD:EE:FF');

      final openPkt = codec.decode(open);
      expect(openPkt.packetType, BlePacketType.openBox);
      expect(openPkt.payload.asJsonMap()?['port'], 3);
    });

    test('portFromBoxId parses BOX labels', () {
      expect(UnlockPacketRequest.portFromBoxId('4'), 4);
      expect(UnlockPacketRequest.portFromBoxId('BOX-03'), 3);
      expect(UnlockPacketRequest.portFromBoxId('Box 12'), 12);
    });
  });

  group('PacketParser', () {
    test('classifies OPEN_ACK unlock success', () {
      const codec = PacketCodec();
      final packet = Packet.build(
        type: BlePacketType.openAck,
        sequenceNumber: 3,
        orderId: 'ORD-1',
        lockerId: 'LCK-A1',
        boxId: 'BOX-03',
        payload: PacketPayload.openAck(opened: true, doorState: 'OPEN'),
      );
      final raw = codec.encode(packet);
      final parsed = PacketParser().parse(raw);
      expect(parsed.kind, BleResponseKind.unlockSuccess);
      expect(parsed.opened, isTrue);
      expect(parsed.doorState, 'OPEN');
      expect(parsed.rawHex, isNotEmpty);
    });

    test('classifies short OPEN_ACK status blob', () {
      final raw = Uint8List.fromList([0x21, 0x01, 0x00, 0x05, 0x02, 0x50]);
      final parsed = PacketParser().parse(raw);
      expect(parsed.kind, BleResponseKind.unlockSuccess);
      expect(parsed.opened, isTrue);
      expect(parsed.doorState, 'OPEN');
    });

    test('unknown short packet', () {
      final raw = Uint8List.fromList([0x99, 0x00]);
      final parsed = PacketParser().parse(raw);
      expect(parsed.kind, BleResponseKind.unknown);
    });
  });

  group('UnlockService + Virtual MCU', () {
    test('end-to-end unlock succeeds without UI', () async {
      final config = BleConfig.development();
      final locker = LockerService(config: config);
      addTearDown(locker.dispose);

      final unlock = UnlockService(locker: locker);
      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      final token = 'CE1.ORD-VM.LCK-A1.BOX-03.$exp.deadbeef';

      final result = await unlock.unlock(
        UnlockPacketRequest(
          transactionId: 'tx-vm',
          orderId: 'ORD-VM',
          lockerId: 'LCK-A1',
          boxId: 'BOX-03',
          port: 3,
          collectionToken: token,
        ),
      );

      expect(result.success, isTrue, reason: result.message);
      expect(result.message, contains('Locker Opened Successfully'));
      expect(result.openResponse?.kind, BleResponseKind.unlockSuccess);
    });

    test('missing token fails fast', () async {
      final locker = LockerService(config: BleConfig.development());
      addTearDown(locker.dispose);
      final unlock = UnlockService(locker: locker);
      final result = await unlock.unlock(
        const UnlockPacketRequest(
          transactionId: 'tx',
          orderId: 'o',
          lockerId: 'LCK',
          boxId: 'BOX',
          port: 1,
          collectionToken: '',
        ),
      );
      expect(result.success, isFalse);
      expect(result.stage, 'payload');
    });
  });
}
