import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/ble.dart';

void main() {
  group('FinalUnlockPort', () {
    test('single-box masks and LE bytes', () {
      expect(FinalUnlockPort.buildPortMask([1]), 0x00000001);
      expect(FinalUnlockPort.encodePort32(0x00000001), [0x01, 0x00, 0x00, 0x00]);

      expect(FinalUnlockPort.buildPortMask([2]), 0x00000002);
      expect(FinalUnlockPort.encodePort32(0x00000002), [0x02, 0x00, 0x00, 0x00]);

      expect(FinalUnlockPort.buildPortMask([8]), 0x00000080);
      expect(FinalUnlockPort.encodePort32(0x00000080), [0x80, 0x00, 0x00, 0x00]);

      expect(FinalUnlockPort.buildPortMask([9]), 0x00000100);
      expect(FinalUnlockPort.encodePort32(0x00000100), [0x00, 0x01, 0x00, 0x00]);

      expect(FinalUnlockPort.buildPortMask([32]), 0x80000000);
      expect(FinalUnlockPort.encodePort32(0x80000000), [0x00, 0x00, 0x00, 0x80]);
    });

    test('multi-box masks', () {
      expect(FinalUnlockPort.buildPortMask([1, 3, 5]), 0x00000015);
      expect(FinalUnlockPort.encodePort32(0x00000015), [0x15, 0x00, 0x00, 0x00]);

      expect(FinalUnlockPort.buildPortMask([1, 3, 5, 32]), 0x80000015);
      expect(FinalUnlockPort.encodePort32(0x80000015), [0x15, 0x00, 0x00, 0x80]);
    });

    test('duplicates collapse', () {
      expect(FinalUnlockPort.buildPortMask([1, 1, 3, 3]), 0x00000005);
    });

    test('invalid boxes throw', () {
      expect(() => FinalUnlockPort.buildPortMask([]), throwsArgumentError);
      expect(() => FinalUnlockPort.buildPortMask([0]), throwsArgumentError);
      expect(() => FinalUnlockPort.buildPortMask([33]), throwsArgumentError);
      expect(() => FinalUnlockPort.buildPortMask([-1]), throwsArgumentError);
    });
  });

  group('FinalUnlockPacketBuilder layout', () {
    late FinalUnlockPacketBuilder builder;

    setUp(() {
      builder = FinalUnlockPacketBuilder(
        mcuCodeFactory: () => Uint8List.fromList([0xAA, 0xBB]),
        tokenSequenceFactory: () => 0x42,
      );
    });

    FinalUnlockPacketRequest req(List<int> boxes, {String tx = 'TX01'}) {
      return FinalUnlockPacketRequest(
        boxNumbers: boxes,
        transactionId: tx,
        startTimeUnixSeconds: 1700000000,
        endTimeUnixSeconds: 1700003600,
        orderId: 'ORD-TEST',
      );
    }

    test('always exactly 32 bytes', () {
      final packet = builder.build(req([1]));
      expect(packet.length, 32);
    });

    test('field offsets for Box 1', () {
      final packet = builder.build(req([1]));

      expect(packet[0], FirmwareCommand.open);

      // Port LE
      expect(packet.sublist(1, 5), [0x01, 0x00, 0x00, 0x00]);

      // Transaction ASCII "TX01"
      expect(packet.sublist(5, 9), [0x54, 0x58, 0x30, 0x31]);

      // MCU
      expect(packet.sublist(9, 11), [0xAA, 0xBB]);

      // Start / End Unix seconds BE (Phase-10 timestamp convention)
      final start = ByteData.sublistView(packet, 11, 15).getUint32(0, Endian.big);
      final end = ByteData.sublistView(packet, 15, 19).getUint32(0, Endian.big);
      expect(start, 1700000000);
      expect(end, 1700003600);

      expect(packet[19], 0x42);

      // Reserved zeros — NOT Phase-20 checksum
      expect(packet.sublist(20, 32), List.filled(12, 0));
    });

    test('matrix Port bytes', () {
      final cases = <(List<int> boxes, List<int> portBytes)>[
        ([1], [0x01, 0x00, 0x00, 0x00]),
        ([2], [0x02, 0x00, 0x00, 0x00]),
        ([8], [0x80, 0x00, 0x00, 0x00]),
        ([9], [0x00, 0x01, 0x00, 0x00]),
        ([1, 3, 5], [0x15, 0x00, 0x00, 0x00]),
        ([32], [0x00, 0x00, 0x00, 0x80]),
        ([1, 3, 5, 32], [0x15, 0x00, 0x00, 0x80]),
      ];

      for (final c in cases) {
        final packet = builder.build(req(c.$1));
        expect(packet.sublist(1, 5), c.$2, reason: 'boxes=${c.$1}');
      }
    });

    test('fresh buffer each build — no shared mutation', () {
      final a = builder.build(req([1]));
      final b = builder.build(req([1]));
      a[1] = 0xFF;
      expect(b[1], 0x01);
    });

    test('transaction pad / reject oversized', () {
      final padded = builder.build(req([1], tx: 'AB'));
      expect(padded.sublist(5, 9), [0x41, 0x42, 0x00, 0x00]);

      expect(
        () => builder.build(req([1], tx: 'ABCDE')),
        throwsArgumentError,
      );
      expect(
        () => builder.build(req([1], tx: '')),
        throwsArgumentError,
      );
    });
  });

  group('consecutive orders — zero Port carry-over', () {
    final builder = FinalUnlockPacketBuilder(
      mcuCodeFactory: () => Uint8List.fromList([0, 0]),
      tokenSequenceFactory: () => 0,
    );

    List<int> portOf(List<int> boxes) {
      final p = builder.build(
        FinalUnlockPacketRequest(
          boxNumbers: boxes,
          transactionId: 'T001',
          startTimeUnixSeconds: 1,
          endTimeUnixSeconds: 2,
        ),
      );
      return p.sublist(1, 5);
    }

    test('A→B→C→D→E sequence ×3', () {
      final sequence = <(List<int> boxes, List<int> portBytes)>[
        ([1], [0x01, 0x00, 0x00, 0x00]),
        ([2], [0x02, 0x00, 0x00, 0x00]),
        ([3, 5], [0x14, 0x00, 0x00, 0x00]), // bits 2+4 = 0x04|0x10
        ([1, 3, 5, 32], [0x15, 0x00, 0x00, 0x80]),
        ([32], [0x00, 0x00, 0x00, 0x80]),
      ];

      for (var round = 0; round < 3; round++) {
        for (final c in sequence) {
          expect(
            portOf(c.$1),
            c.$2,
            reason: 'round=$round boxes=${c.$1}',
          );
        }
      }
    });
  });

  group('repeat same order — Port stable; random fields vary', () {
    test('10 builds: Port identical; MCU/token may differ', () {
      final builder = FinalUnlockPacketBuilder(); // real random
      final ports = <String>[];
      final mcus = <String>[];
      final tokens = <int>[];

      for (var i = 0; i < 10; i++) {
        final p = builder.build(
          FinalUnlockPacketRequest(
            boxNumbers: const [1, 3, 5],
            transactionId: 'TX99',
            startTimeUnixSeconds: 100,
            endTimeUnixSeconds: 200,
          ),
        );
        expect(p.length, 32);
        ports.add(p.sublist(1, 5).join(','));
        mcus.add(p.sublist(9, 11).join(','));
        tokens.add(p[19]);
        // Fixed fields
        expect(p[0], FirmwareCommand.open);
        expect(p.sublist(5, 9), [0x54, 0x58, 0x39, 0x39]);
        expect(p.sublist(20, 32), List.filled(12, 0));
      }

      expect(ports.toSet().length, 1);
      expect(ports.first, '21,0,0,0'); // 0x15
    });
  });

  group('buildCollect — Collect wiring path', () {
    test('Command 0x01 + Port from boxes; length 32', () {
      final builder = FinalUnlockPacketBuilder();
      final packet = builder.buildCollect(boxNumbers: const [1, 3, 5]);
      expect(packet.length, 32);
      expect(packet[0], 0x01);
      expect(packet.sublist(1, 5), [0x15, 0x00, 0x00, 0x00]);
      expect(packet.sublist(20, 32), List.filled(12, 0));
    });

    test('A→B→C→D→E Port sequence via buildCollect', () {
      final builder = FinalUnlockPacketBuilder();
      final sequence = <(List<int>, List<int>)>[
        ([1], [0x01, 0x00, 0x00, 0x00]),
        ([2], [0x02, 0x00, 0x00, 0x00]),
        ([3, 5], [0x14, 0x00, 0x00, 0x00]),
        ([1, 3, 5, 32], [0x15, 0x00, 0x00, 0x80]),
        ([32], [0x00, 0x00, 0x00, 0x80]),
        ([4], [0x08, 0x00, 0x00, 0x00]),
        ([2, 5], [0x12, 0x00, 0x00, 0x00]),
      ];
      for (var round = 0; round < 3; round++) {
        for (final c in sequence) {
          final p = builder.buildCollect(boxNumbers: c.$1);
          expect(p[0], 0x01);
          expect(p.sublist(1, 5), c.$2, reason: 'round=$round boxes=${c.$1}');
        }
      }
    });

    test('long order id does not block Collect placeholders', () {
      final p = FinalUnlockPacketBuilder().buildCollect(
        boxNumbers: const [1],
        orderId: 'ORD-VERY-LONG-IDENTIFIER-12345',
      );
      expect(p.length, 32);
      expect(p[0], 0x01);
      expect(p.sublist(1, 5), [0x01, 0x00, 0x00, 0x00]);
    });
  });

  group('encodeTimestamp32', () {
    test('Unix seconds big-endian', () {
      final bytes = FinalUnlockPacketBuilder.encodeTimestamp32(0x01020304);
      expect(bytes, [0x01, 0x02, 0x03, 0x04]);
    });
  });
}
