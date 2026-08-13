import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/ble.dart';

void main() {
  group('Phase 29 — packet identity across repeated builds', () {
    const builder = RealPacketBuilder();

    UnlockPacketRequest req({
      required List<int> boxes,
      int port = 1,
      int terminal = 1,
    }) {
      return UnlockPacketRequest(
        transactionId: 'TX1234',
        orderId: 'ORD12345',
        lockerId: 'LCK',
        boxId: '${boxes.first}',
        collectionToken: 'tok',
        port: port,
        boxNumber: boxes.first,
        boxNumbers: boxes,
        terminalNumber: terminal,
        itemId: 'ITEM0001',
      );
    }

    void expectFiveIdentical(UnlockPacketRequest request) {
      final packets = List.generate(
        5,
        (_) => builder.buildOpen(request),
      );
      for (final p in packets) {
        expect(p.length, 32);
      }
      final hex0 = packets[0]
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      for (var i = 1; i < packets.length; i++) {
        final hex = packets[i]
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        expect(hex, hex0, reason: 'SEND ${i + 1} must match SEND 1');
        expect(
          identical(packets[i], packets[0]),
          isFalse,
          reason: 'each build must allocate a fresh Uint8List',
        );
      }
    }

    test('same packet ×5 — Box 1', () {
      expectFiveIdentical(req(boxes: [1]));
    });

    test('same packet ×5 — Box 2', () {
      expectFiveIdentical(req(boxes: [2], port: 2));
    });

    test('same packet ×5 — Box 1+3', () {
      expectFiveIdentical(req(boxes: [1, 3]));
    });

    test('same packet ×5 — Box 1+3+5+32', () {
      expectFiveIdentical(req(boxes: [1, 3, 5, 32]));
    });
  });

  group('Phase 29 — BleWritePayload chunking', () {
    test('single chunk when MTU payload fits 32 bytes', () {
      final packet = Uint8List.fromList(List.generate(32, (i) => i));
      final chunks = BleWritePayload.splitForAttPayload(
        packet,
        maxPayload: 64, // MTU≥67 → att payload ≥64
      );
      expect(chunks, hasLength(1));
      expect(chunks.first, packet);
      expect(identical(chunks.first, packet), isFalse);
    });

    test('deterministic split reconstructs original', () {
      final packet = Uint8List.fromList(List.generate(32, (i) => 0xA0 + i));
      final chunks = BleWritePayload.splitForAttPayload(
        packet,
        maxPayload: 20,
      );
      expect(chunks, hasLength(2));
      expect(chunks[0].length, 20);
      expect(chunks[1].length, 12);
      expect(BleWritePayload.concatenate(chunks), packet);
    });

    test('mutating source after copy does not affect chunk', () {
      final packet = Uint8List(32);
      packet[0] = 0x01;
      final chunks = BleWritePayload.splitForAttPayload(
        packet,
        maxPayload: 32,
      );
      packet[0] = 0xFF;
      expect(chunks.first[0], 0x01);
    });
  });
}
