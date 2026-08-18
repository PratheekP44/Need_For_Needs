import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/protocol/ble_response_observation.dart';

void main() {
  group('BleResponseObservation.inspect', () {
    test('empty response', () {
      final obs = BleResponseObservation.inspect(Uint8List(0));
      expect(obs.length, 0);
      expect(obs.bytesDec, isEmpty);
      expect(obs.bytesHex, '');
      expect(obs.byte0, isNull);
      expect(obs.byte1, isNull);
      expect(obs.byte4, isNull);
      expect(obs.remainingAfterIndex4, isEmpty);
    });

    test('one-byte response', () {
      final obs = BleResponseObservation.inspect(Uint8List.fromList([0x02]));
      expect(obs.length, 1);
      expect(obs.byte0, 0x02);
      expect(obs.byte0CandidateNote, contains('Command Response'));
      expect(obs.byte1, isNull);
      expect(obs.byte4, isNull);
    });

    test('four-byte response has no byte4', () {
      final obs = BleResponseObservation.inspect(
        Uint8List.fromList([0x02, 0x00, 0x00, 0x00]),
      );
      expect(obs.length, 4);
      expect(obs.byte0, 0x02);
      expect(obs.byte1, 0x00);
      expect(obs.pendingCandidateNote, contains('DONE'));
      expect(obs.byte4, isNull);
      expect(obs.remainingAfterIndex4, isEmpty);
    });

    test('five-byte response exposes locker state candidate', () {
      final obs = BleResponseObservation.inspect(
        Uint8List.fromList([0x02, 0x00, 0x00, 0x00, 0x04]),
      );
      expect(obs.length, 5);
      expect(obs.byte4, 0x04);
      expect(obs.lockerStateCandidateNote, contains('OPEN'));
      expect(obs.remainingAfterIndex4, isEmpty);
    });

    test('pending candidate YES when [1]=1', () {
      final obs = BleResponseObservation.inspect(
        Uint8List.fromList([0x02, 0x01]),
      );
      expect(obs.byte0, 0x02);
      expect(obs.byte1, 1);
      expect(obs.pendingCandidateNote, contains('YES'));
    });

    test('pending DONE and open candidate when [1]=0 [4]=0x04', () {
      final obs = BleResponseObservation.inspect(
        Uint8List.fromList([0x02, 0x00, 0xAA, 0xBB, 0x04]),
      );
      expect(obs.byte0, 0x02);
      expect(obs.byte1, 0);
      expect(obs.pendingCandidateNote, contains('DONE'));
      expect(obs.byte4, 0x04);
      expect(obs.lockerStateCandidateNote, contains('OPEN'));
    });

    test('unknown byte 0 stays unknown', () {
      final obs = BleResponseObservation.inspect(Uint8List.fromList([0x99]));
      expect(obs.byte0, 0x99);
      expect(obs.byte0CandidateNote, contains('unknown'));
    });

    test('unknown byte 1 stays unknown', () {
      final obs = BleResponseObservation.inspect(
        Uint8List.fromList([0x02, 0x07]),
      );
      expect(obs.byte1, 0x07);
      expect(obs.pendingCandidateNote, contains('unknown'));
    });

    test('unknown byte 4 stays unknown', () {
      final obs = BleResponseObservation.inspect(
        Uint8List.fromList([0x02, 0x00, 0x00, 0x00, 0x05]),
      );
      expect(obs.byte4, 0x05);
      expect(obs.lockerStateCandidateNote, contains('unknown'));
    });

    test('long response preserves remaining bytes without meaning', () {
      final raw = Uint8List.fromList([
        0x02, 0x00, 0x11, 0x22, 0x04, 0xAB, 0xCD, 0xEF,
      ]);
      final obs = BleResponseObservation.inspect(raw, sequence: 2);
      expect(obs.sequence, 2);
      expect(obs.length, 8);
      expect(obs.remainingAfterIndex4, [0xAB, 0xCD, 0xEF]);
      expect(obs.bytesDec, [0x02, 0x00, 0x11, 0x22, 0x04, 0xAB, 0xCD, 0xEF]);
      expect(obs.bytesHex, '02 00 11 22 04 ab cd ef');
    });

    test('raw bytes preserved exactly', () {
      final raw = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
      final obs = BleResponseObservation.inspect(raw);
      expect(obs.bytesDec, [1, 2, 3, 4, 5, 6]);
      expect(obs.length, raw.length);
    });

    test('does not mutate original buffer', () {
      final raw = Uint8List.fromList([0x02, 0x00, 0x00, 0x00, 0x04]);
      final before = List<int>.from(raw);
      final obs = BleResponseObservation.inspect(raw);
      expect(List<int>.from(raw), before);
      expect(() => (obs.bytesDec as List).add(99), throwsUnsupportedError);
    });
  });
}
