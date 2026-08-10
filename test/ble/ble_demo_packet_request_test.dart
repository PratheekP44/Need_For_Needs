import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/ble.dart';
import 'package:need_for_needs/features/ble_demo/models/ble_demo_packet_request.dart';

void main() {
  group('BleDemoPacketRequest', () {
    test('maps multi-box to RealPacketBuilder 32-byte OPEN', () {
      const demo = BleDemoPacketRequest(
        command: FirmwareCommand.open,
        port: 1,
        boxNumbers: [1],
        terminalNumber: 1,
        orderId: 'ORD1',
        itemId: 'ITEM1',
        transactionId: 'TX1',
      );

      const builder = RealPacketBuilder();
      final packet = builder.build(
        command: demo.command,
        request: demo.toUnlockPacketRequest(),
      );

      expect(packet.length, 32);
      expect(packet[0], FirmwareCommand.open);
      expect(packet[1], 1);
      expect(packet.sublist(2, 6), [0x01, 0x00, 0x00, 0x00]);
      expect(packet[6], 1);
    });

    test('CUSTOM opcode with multi-box', () {
      const demo = BleDemoPacketRequest(
        command: 0xAB,
        port: 2,
        boxNumbers: [2, 3],
        terminalNumber: 4,
      );
      const builder = RealPacketBuilder();
      final packet = builder.build(
        command: demo.command,
        request: demo.toUnlockPacketRequest(),
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
