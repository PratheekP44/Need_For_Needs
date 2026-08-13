import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/ble.dart';

void main() {
  group('RealPacketBuilder (Collect / production path)', () {
    test('maps multi-box to 32-byte OPEN', () {
      const request = UnlockPacketRequest(
        transactionId: 'TX1',
        orderId: 'ORD1',
        lockerId: 'LCK',
        boxId: '1',
        collectionToken: 'tok',
        port: 1,
        boxNumber: 1,
        boxNumbers: [1],
        terminalNumber: 1,
        itemId: 'ITEM1',
      );

      const builder = RealPacketBuilder();
      final packet = builder.build(
        command: FirmwareCommand.open,
        request: request,
      );

      expect(packet.length, 32);
      expect(packet[0], FirmwareCommand.open);
      expect(packet[1], 1);
      expect(packet.sublist(2, 6), [0x01, 0x00, 0x00, 0x00]);
      expect(packet[6], 1);
    });

    test('CUSTOM opcode with multi-box', () {
      const request = UnlockPacketRequest(
        transactionId: 'TX',
        orderId: 'ORD',
        lockerId: 'LCK',
        boxId: '2',
        collectionToken: 'tok',
        port: 2,
        boxNumber: 2,
        boxNumbers: [2, 3],
        terminalNumber: 4,
      );
      const builder = RealPacketBuilder();
      final packet = builder.build(
        command: 0xAB,
        request: request,
      );
      expect(packet.length, 32);
      expect(packet[0], 0xAB);
      expect(packet[1], 2);
      // bits 1+2 = 0x06
      expect(packet.sublist(2, 6), [0x06, 0x00, 0x00, 0x00]);
      expect(packet[6], 4);
    });
  });
}
