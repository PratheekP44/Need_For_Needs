import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/ble.dart';

void main() {
  group('Phase 31 — CollectBleProfiler', () {
    test('records stage deltas and spans', () async {
      final p = CollectBleProfiler();
      p.mark('SCAN_START');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      p.mark('SCAN_STOP');
      p.mark('CONNECT_START');
      await Future<void>.delayed(const Duration(milliseconds: 15));
      p.mark('CONNECTED');
      p.mark('WRITE_START');
      p.mark('WRITE_COMPLETE');
      p.mark('RESPONSE_RECEIVED');
      p.mark('UNLOCK_SUCCESS');

      expect(p.elapsedMs, greaterThanOrEqualTo(30));
      expect(p.atOf('SCAN_START'), isNotNull);
      expect(p.atOf('UNLOCK_SUCCESS'), isNotNull);
      p.report(success: true, note: 'unit');
    });
  });

  group('Phase 31 — hardware scan defaults', () {
    test('scan ceiling is ≤5s (no 15s floor)', () {
      final cfg = BleConfig.hardware();
      expect(cfg.scanTimeout.inSeconds, lessThanOrEqualTo(5));
      expect(cfg.connectTimeout.inSeconds, lessThanOrEqualTo(10));
      expect(cfg.targetDeviceName, 'LKRM-V2');
      expect(cfg.postConnectSettle, Duration.zero);
      expect(cfg.postMtuSettle, Duration.zero);
      expect(cfg.postDiscoverSettle, Duration.zero);
      expect(cfg.postNotifySettle, Duration.zero);
    });
  });

  group('Phase 31 — packet identity ×10', () {
    const builder = RealPacketBuilder();

    UnlockPacketRequest req(List<int> boxes) => UnlockPacketRequest(
          transactionId: 'TX1234',
          orderId: 'ORD12345',
          lockerId: 'LCK',
          boxId: '${boxes.first}',
          collectionToken: 'tok',
          port: boxes.first,
          boxNumber: boxes.first,
          boxNumbers: boxes,
          terminalNumber: 1,
          itemId: 'ITEM0001',
        );

    String hex(List<int> bytes) =>
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    test('Box 1 packet identical across 10 builds', () {
      final request = req([1]);
      final first = builder.build(
        command: FirmwareCommand.open,
        request: request,
      );
      expect(first.length, 32);
      for (var i = 0; i < 10; i++) {
        final again = builder.build(
          command: FirmwareCommand.open,
          request: request,
        );
        expect(hex(again), hex(first), reason: 'attempt ${i + 1}');
      }
    });

    test('Box 2 and multi-box packets stable ×10', () {
      for (final boxes in [
        [2],
        [1, 3, 5],
      ]) {
        final request = req(boxes);
        final first = builder.build(
          command: FirmwareCommand.open,
          request: request,
        );
        for (var i = 0; i < 10; i++) {
          final again = builder.build(
            command: FirmwareCommand.open,
            request: request,
          );
          expect(hex(again), hex(first));
        }
      }
    });
  });
}
