import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/ble.dart';
import 'package:need_for_needs/features/ble_demo/models/ble_demo_packet_request.dart';

void main() {
  group('BleDemoPacketRequest', () {
    test('maps to RealPacketBuilder 32-byte OPEN packet', () {
      const demo = BleDemoPacketRequest(
        command: FirmwareCommand.open,
        port: 1,
        boxNumber: 1,
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
      expect(packet[2], 1);
      expect(packet[3], 1);
      expect(
        String.fromCharCodes(packet.sublist(4, 12)).replaceAll('\u0000', ''),
        'ORD1',
      );
      expect(
        String.fromCharCodes(packet.sublist(12, 20)).replaceAll('\u0000', ''),
        'ITEM1',
      );
      expect(
        String.fromCharCodes(packet.sublist(20, 28)).replaceAll('\u0000', ''),
        'TX1',
      );
      expect(packet[28], 0);
      expect(packet[29], 0);

      final body = Uint8List.sublistView(packet, 0, 30);
      final expected = computeChecksumPlaceholder(body);
      final actual = ByteData.sublistView(packet).getUint16(30, Endian.big);
      expect(actual, expected);
    });

    test('CUSTOM opcode passes through builder', () {
      const demo = BleDemoPacketRequest(
        command: 0xAB,
        port: 2,
        boxNumber: 3,
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
      expect(packet[2], 3);
      expect(packet[3], 4);
    });
  });
}
