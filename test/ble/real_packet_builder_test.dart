import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/ble.dart';

void main() {
  group('RealPacketBuilder', () {
    test('builds exactly 32 bytes with fixed field layout', () {
      const builder = RealPacketBuilder();
      const request = UnlockPacketRequest(
        transactionId: 'TX12345678',
        orderId: 'ORD-0001',
        lockerId: 'LCK-02',
        boxId: 'BOX-03',
        port: 3,
        boxNumber: 3,
        terminalNumber: 2,
        itemId: 'ITEM0042',
        collectionToken: 'CE1.ORD-0001.LCK-02.BOX-03.1893456000.deadbeef',
      );

      final packet = builder.buildOpen(request);

      expect(packet.length, RealPacketBuilder.packetLength);
      expect(packet.length, 32);

      expect(packet[0], FirmwareCommand.open); // Command
      expect(packet[1], 3); // Port
      expect(packet[2], 3); // Box
      expect(packet[3], 2); // Terminal

      // Order ID "ORD-0001" at bytes 4..11
      expect(
        String.fromCharCodes(packet.sublist(4, 12)).replaceAll('\u0000', ''),
        'ORD-0001',
      );
      // Item ID
      expect(
        String.fromCharCodes(packet.sublist(12, 20)).replaceAll('\u0000', ''),
        'ITEM0042',
      );
      // Transaction ID truncated/padded to 8
      expect(
        String.fromCharCodes(packet.sublist(20, 28)).replaceAll('\u0000', ''),
        'TX123456',
      );
      // Reserved
      expect(packet[28], 0);
      expect(packet[29], 0);

      // Checksum = placeholder over body[0..29]
      final body = Uint8List.sublistView(packet, 0, 30);
      final expected = computeChecksumPlaceholder(body);
      final actual = ByteData.sublistView(packet).getUint16(30, Endian.big);
      expect(actual, expected);
    });

    test('unused app-data bytes are 0x00', () {
      const builder = RealPacketBuilder();
      const request = UnlockPacketRequest(
        transactionId: 'T',
        orderId: 'O',
        lockerId: 'L1',
        boxId: '1',
        port: 1,
        collectionToken: 'CE1.O.L1.1.1893456000.deadbeef',
      );
      final packet = builder.buildOpen(request);
      expect(packet.length, 32);
      expect(packet[0], FirmwareCommand.open);
      expect(packet[1], 1);
      expect(packet[2], 1);
      expect(packet[3], 1);
      // Only first ASCII byte of each field set; rest of field + reserved = 0
      expect(packet[5], 0);
      expect(packet[13], 0);
      expect(packet[21], 0);
      expect(packet[28], 0);
      expect(packet[29], 0);
    });
  });
}
