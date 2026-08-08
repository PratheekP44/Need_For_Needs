import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/api/collect_unlock_repository.dart';
import 'package:need_for_needs/core/ble/ble.dart';

void main() {
  group('CollectUnlockInfo dynamic packet mapping (Phase 18)', () {
    test('parses unlock-info JSON including port alias', () {
      final info = CollectUnlockInfo.fromJson({
        'orderId': 'ord123',
        'lockerId': 'LCK-01',
        'terminalNumber': 2,
        'boxNumber': 5,
        'port': 5,
        'itemId': 'ITEM42',
        'transactionId': 'TX9',
        'orderNumber': 'ORD-9',
      });
      expect(info.boxNumber, 5);
      expect(info.port, 5);
      expect(info.terminalNumber, 2);
    });

    test('toUnlockPacketRequest maps Port = Box from order (never hardcoded)',
        () {
      for (final box in [1, 5, 8]) {
        final info = CollectUnlockInfo(
          orderId: 'ord-$box',
          lockerId: 'LCK-01',
          terminalNumber: 3,
          boxNumber: box,
          itemId: 'SKU$box',
          transactionId: 'TX$box',
        );
        final request = info.toUnlockPacketRequest();
        expect(request.port, box);
        expect(request.boxNumber, box);
        expect(request.effectiveBoxNumber, box);
        expect(request.terminalNumber, 3);

        const builder = RealPacketBuilder();
        final packet = builder.buildOpen(request);
        expect(packet.length, 32);
        expect(packet[0], FirmwareCommand.open);
        expect(packet[1], box, reason: 'Byte1 Port must be order box $box');
        expect(packet[2], box, reason: 'Byte2 Box must be order box $box');
        expect(packet[3], 3, reason: 'Byte3 Terminal from locker');
      }
    });

    test('Box 5 and Box 8 produce different Port bytes than Box 1', () {
      const builder = RealPacketBuilder();
      Uint8List packetFor(int box) {
        return builder.buildOpen(
          CollectUnlockInfo(
            orderId: 'o',
            lockerId: 'L',
            terminalNumber: 1,
            boxNumber: box,
          ).toUnlockPacketRequest(),
        );
      }

      final p1 = packetFor(1);
      final p5 = packetFor(5);
      final p8 = packetFor(8);
      expect(p1[1], 1);
      expect(p5[1], 5);
      expect(p8[1], 8);
      expect(p1[1], isNot(p5[1]));
      expect(p5[1], isNot(p8[1]));
    });
  });
}
