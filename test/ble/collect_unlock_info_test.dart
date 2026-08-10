import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/api/collect_unlock_repository.dart';
import 'package:need_for_needs/core/ble/ble.dart';

void main() {
  group('CollectUnlockInfo Phase 20', () {
    test('parses boxNumbers array and port', () {
      final info = CollectUnlockInfo.fromJson({
        'orderId': 'ord123',
        'lockerId': 'LCK-01',
        'terminalNumber': 2,
        'port': 5,
        'boxNumber': 5,
        'boxNumbers': [1, 3, 5],
        'itemId': 'ITEM42',
        'transactionId': 'TX9',
        'orderNumber': 'ORD-9',
      });
      expect(info.port, 5);
      expect(info.boxNumbers, [1, 3, 5]);
      expect(info.terminalNumber, 2);
    });

    test('falls back to single boxNumber', () {
      final info = CollectUnlockInfo.fromJson({
        'orderId': 'ord123',
        'lockerId': 'LCK-01',
        'terminalNumber': 1,
        'boxNumber': 8,
      });
      expect(info.port, 8);
      expect(info.boxNumbers, [8]);
    });

    test('toUnlockPacketRequest maps multi-box bitmap fields', () {
      const info = CollectUnlockInfo(
        orderId: 'ord-5',
        lockerId: 'LCK-01',
        terminalNumber: 3,
        port: 5,
        boxNumbers: [1, 3, 5],
        itemId: 'SKU1',
        transactionId: 'TX1',
      );
      final request = info.toUnlockPacketRequest();
      expect(request.port, 5);
      expect(request.terminalNumber, 3);
      expect(request.effectiveBoxNumbers, [1, 3, 5]);

      const builder = RealPacketBuilder();
      final packet = builder.buildOpen(request);
      expect(packet.length, 32);
      expect(packet[0], FirmwareCommand.open);
      expect(packet[1], 5);
      expect(packet.sublist(2, 6), [0x15, 0x00, 0x00, 0x00]);
      expect(packet[6], 3);
    });
  });
}
