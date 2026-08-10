import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/ble.dart';

void main() {
  group('BoxUnlockMask.buildBoxUnlockMask', () {
    test('single boxes', () {
      expect(BoxUnlockMask.buildBoxUnlockMask([1]), 0x00000001);
      expect(BoxUnlockMask.buildBoxUnlockMask([2]), 0x00000002);
      expect(BoxUnlockMask.buildBoxUnlockMask([3]), 0x00000004);
      expect(BoxUnlockMask.buildBoxUnlockMask([5]), 0x00000010);
      expect(BoxUnlockMask.buildBoxUnlockMask([8]), 0x00000080);
      expect(BoxUnlockMask.buildBoxUnlockMask([16]), 0x00008000);
      expect(BoxUnlockMask.buildBoxUnlockMask([31]), 0x40000000);
      expect(BoxUnlockMask.buildBoxUnlockMask([32]), 0x80000000);
    });

    test('multi-box combinations', () {
      expect(BoxUnlockMask.buildBoxUnlockMask([1, 3, 5]), 0x00000015);
      expect(BoxUnlockMask.buildBoxUnlockMask([2, 5, 8]), 0x00000092);
      expect(BoxUnlockMask.buildBoxUnlockMask([1, 3, 5, 32]), 0x80000015);
    });

    test('deduplicates boxes', () {
      expect(BoxUnlockMask.buildBoxUnlockMask([1, 1, 3, 3, 5]), 0x00000015);
    });

    test('rejects empty / invalid', () {
      expect(() => BoxUnlockMask.buildBoxUnlockMask([]), throwsArgumentError);
      expect(() => BoxUnlockMask.buildBoxUnlockMask([0]), throwsArgumentError);
      expect(() => BoxUnlockMask.buildBoxUnlockMask([33]), throwsArgumentError);
    });

    test('all 32 boxes', () {
      final boxes = List<int>.generate(32, (i) => i + 1);
      final mask = BoxUnlockMask.buildBoxUnlockMask(boxes);
      expect(mask, 0xFFFFFFFF);
    });
  });

  group('BoxUnlockMask.encodeBoxMask32', () {
    test('little-endian: Box 1 → first byte 0x01', () {
      final bytes = BoxUnlockMask.encodeBoxMask32(0x00000001);
      expect(bytes.length, 4);
      expect(bytes, [0x01, 0x00, 0x00, 0x00]);
    });

    test('little-endian: Box 32 → last byte 0x80', () {
      final bytes = BoxUnlockMask.encodeBoxMask32(0x80000000);
      expect(bytes, [0x00, 0x00, 0x00, 0x80]);
    });

    test('little-endian: 0x00000015 → 15 00 00 00', () {
      final bytes = BoxUnlockMask.encodeBoxMask32(0x00000015);
      expect(bytes, [0x15, 0x00, 0x00, 0x00]);
    });
  });

  group('RealPacketBuilder Phase 20 layout', () {
    const builder = RealPacketBuilder();

    UnlockPacketRequest req({
      int port = 5,
      List<int> boxes = const [5],
      int terminal = 1,
      String orderId = 'ORD-0001',
      String itemId = 'ITEM0042',
      String tx = 'TX1234',
    }) {
      return UnlockPacketRequest(
        transactionId: tx,
        orderId: orderId,
        lockerId: 'LCK-01',
        boxId: '${boxes.first}',
        port: port,
        boxNumber: boxes.first,
        boxNumbers: boxes,
        terminalNumber: terminal,
        itemId: itemId,
        collectionToken: 'collect',
      );
    }

    test('packet length exactly 32', () {
      final packet = builder.buildOpen(req());
      expect(packet.length, 32);
    });

    test('Box 5 layout fields', () {
      final packet = builder.buildOpen(req(port: 5, boxes: const [5]));
      expect(packet[0], FirmwareCommand.open);
      expect(packet[1], 5); // Port
      // Bitmap LE for 0x00000010
      expect(packet.sublist(2, 6), [0x10, 0x00, 0x00, 0x00]);
      expect(packet[6], 1); // Terminal
      expect(
        String.fromCharCodes(packet.sublist(7, 15)).replaceAll('\u0000', ''),
        'ORD-0001',
      );
      expect(
        String.fromCharCodes(packet.sublist(15, 23)).replaceAll('\u0000', ''),
        'ITEM0042',
      );
      expect(
        String.fromCharCodes(packet.sublist(23, 29)).replaceAll('\u0000', ''),
        'TX1234',
      );
      expect(packet[29], 0);
      final body = Uint8List.sublistView(packet, 0, 30);
      final expected = computeChecksumPlaceholder(body);
      final actual = ByteData.sublistView(packet).getUint16(30, Endian.big);
      expect(actual, expected);
    });

    test('Box 1 bitmap bytes', () {
      final packet = builder.buildOpen(req(port: 1, boxes: const [1]));
      expect(packet.sublist(2, 6), [0x01, 0x00, 0x00, 0x00]);
    });

    test('multi-box [1,3,5] bitmap', () {
      final packet =
          builder.buildOpen(req(port: 1, boxes: const [1, 3, 5]));
      expect(packet.sublist(2, 6), [0x15, 0x00, 0x00, 0x00]);
    });

    test('checksum changes when bitmap changes', () {
      final a = builder.buildOpen(req(boxes: const [1]));
      final b = builder.buildOpen(req(boxes: const [5]));
      expect(a.sublist(30, 32), isNot(equals(b.sublist(30, 32))));
    });

    test('changing terminal changes packet', () {
      final a = builder.buildOpen(req(terminal: 1));
      final b = builder.buildOpen(req(terminal: 2));
      expect(a[6], 1);
      expect(b[6], 2);
      expect(a, isNot(equals(b)));
    });

    test('changing order ID changes packet', () {
      final a = builder.buildOpen(req(orderId: 'AAAA'));
      final b = builder.buildOpen(req(orderId: 'BBBB'));
      expect(a, isNot(equals(b)));
    });

    test('transaction ID truncated to 6 bytes', () {
      final packet = builder.buildOpen(req(tx: 'ABCDEFGH'));
      expect(
        String.fromCharCodes(packet.sublist(23, 29)),
        'ABCDEF',
      );
    });
  });
}
