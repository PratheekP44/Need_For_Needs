import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/protocol/final_unlock_response_parser.dart';

Uint8List _rx(List<int> bytes) => Uint8List.fromList(bytes);

/// Live-shaped 16-byte response helper.
Uint8List liveLike({required int b0, required int b1, required int b4}) {
  return _rx([
    b0, b1, 0x00, 0x00, b4,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ]);
}

void main() {
  group('FinalUnlockResponseParser', () {
    test('valid pending response 02 01 … A1 → pending not success', () {
      final p = FinalUnlockResponseParser.parse(
        liveLike(b0: 0x02, b1: 0x01, b4: 0xA1),
      );
      expect(p.isPending, isTrue);
      expect(p.isSuccess, isFalse);
      expect(p.isError, isFalse);
      expect(p.result, FinalUnlockRxResult.processing);
    });

    test('valid completed response 02 00 … A1 → success', () {
      final p = FinalUnlockResponseParser.parse(
        liveLike(b0: 0x02, b1: 0x00, b4: 0xA1),
      );
      expect(p.isSuccess, isTrue);
      expect(p.isPending, isFalse);
      expect(p.type, FinalUnlockRxType.commandResponse);
      expect(p.commandState, FinalUnlockRxCommandState.complete);
      expect(p.result, FinalUnlockRxResult.unlocked);
    });

    test('error response 04 … → error not success', () {
      final p = FinalUnlockResponseParser.parse(
        liveLike(b0: 0x04, b1: 0x00, b4: 0x00),
      );
      expect(p.isError, isTrue);
      expect(p.isSuccess, isFalse);
      expect(p.isPending, isFalse);
    });

    test('short response <5 → invalid', () {
      final p = FinalUnlockResponseParser.parse(_rx([0x02, 0x00, 0x00, 0x00]));
      expect(p.isInvalid, isTrue);
      expect(p.isSuccess, isFalse);
    });

    test('unknown command response → unknown / not success', () {
      final p = FinalUnlockResponseParser.parse(
        liveLike(b0: 0x99, b1: 0x00, b4: 0xA1),
      );
      expect(p.isUnknown, isTrue);
      expect(p.isSuccess, isFalse);
    });

    test('complete without A1 is not success', () {
      final p = FinalUnlockResponseParser.parse(
        liveLike(b0: 0x02, b1: 0x00, b4: 0x04),
      );
      expect(p.isSuccess, isFalse);
      expect(p.commandState, FinalUnlockRxCommandState.complete);
    });

    test('byte0 alone 0x02 is not success', () {
      final p = FinalUnlockResponseParser.parse(
        liveLike(b0: 0x02, b1: 0x01, b4: 0x00),
      );
      expect(p.isSuccess, isFalse);
    });

    test('byte1 alone 0x00 is not success', () {
      final p = FinalUnlockResponseParser.parse(
        liveLike(b0: 0x04, b1: 0x00, b4: 0xA1),
      );
      expect(p.isSuccess, isFalse);
    });

    test('byte4 alone 0xA1 is not success', () {
      final p = FinalUnlockResponseParser.parse(
        liveLike(b0: 0x02, b1: 0x01, b4: 0xA1),
      );
      expect(p.isSuccess, isFalse);
      expect(p.isPending, isTrue);
    });
  });

  group('FinalUnlockResponseTracker', () {
    test('pending does NOT count as success', () {
      final t = FinalUnlockResponseTracker(expectedCommands: 1);
      final step = t.apply(
        FinalUnlockResponseParser.parse(
          liveLike(b0: 0x02, b1: 0x01, b4: 0xA1),
        ),
      );
      expect(step.action, FinalUnlockTrackAction.continueWaiting);
      expect(t.successfulCommands, 0);
    });

    test('complete A1 counts as success', () {
      final t = FinalUnlockResponseTracker(expectedCommands: 1);
      final step = t.apply(
        FinalUnlockResponseParser.parse(
          liveLike(b0: 0x02, b1: 0x00, b4: 0xA1),
        ),
      );
      expect(step.action, FinalUnlockTrackAction.allSucceeded);
      expect(t.successfulCommands, 1);
    });

    test('one-box: pending then complete → one success', () {
      final t = FinalUnlockResponseTracker(expectedCommands: 1);
      expect(
        t
            .apply(
              FinalUnlockResponseParser.parse(
                liveLike(b0: 0x02, b1: 0x01, b4: 0xA1),
              ),
            )
            .action,
        FinalUnlockTrackAction.continueWaiting,
      );
      final done = t.apply(
        FinalUnlockResponseParser.parse(
          liveLike(b0: 0x02, b1: 0x00, b4: 0xA1),
        ),
      );
      expect(done.action, FinalUnlockTrackAction.allSucceeded);
      expect(t.successfulCommands, 1);
      expect(t.notificationIndex, 2);
    });

    test('three-box: three completes → succeeds', () {
      final t = FinalUnlockResponseTracker(expectedCommands: 3);
      for (var i = 0; i < 2; i++) {
        final step = t.apply(
          FinalUnlockResponseParser.parse(
            liveLike(b0: 0x02, b1: 0x00, b4: 0xA1),
          ),
        );
        expect(step.action, FinalUnlockTrackAction.progress);
      }
      final last = t.apply(
        FinalUnlockResponseParser.parse(
          liveLike(b0: 0x02, b1: 0x00, b4: 0xA1),
        ),
      );
      expect(last.action, FinalUnlockTrackAction.allSucceeded);
      expect(t.successfulCommands, 3);
    });

    test('three-box: success success error → fails; partial count kept', () {
      final t = FinalUnlockResponseTracker(expectedCommands: 3);
      t.apply(
        FinalUnlockResponseParser.parse(
          liveLike(b0: 0x02, b1: 0x00, b4: 0xA1),
        ),
      );
      t.apply(
        FinalUnlockResponseParser.parse(
          liveLike(b0: 0x02, b1: 0x00, b4: 0xA1),
        ),
      );
      final fail = t.apply(
        FinalUnlockResponseParser.parse(
          liveLike(b0: 0x04, b1: 0x00, b4: 0x00),
        ),
      );
      expect(fail.action, FinalUnlockTrackAction.failed);
      expect(t.successfulCommands, 2);
      expect(fail.failedNotificationIndex, 3);
    });

    test('five-box: all five successful', () {
      final t = FinalUnlockResponseTracker(expectedCommands: 5);
      for (var i = 0; i < 4; i++) {
        expect(
          t
              .apply(
                FinalUnlockResponseParser.parse(
                  liveLike(b0: 0x02, b1: 0x00, b4: 0xA1),
                ),
              )
              .action,
          FinalUnlockTrackAction.progress,
        );
      }
      expect(
        t
            .apply(
              FinalUnlockResponseParser.parse(
                liveLike(b0: 0x02, b1: 0x00, b4: 0xA1),
              ),
            )
            .action,
        FinalUnlockTrackAction.allSucceeded,
      );
      expect(t.successfulCommands, 5);
    });

    test('invalid short response fails tracker', () {
      final t = FinalUnlockResponseTracker(expectedCommands: 1);
      final step = t.apply(
        FinalUnlockResponseParser.parse(_rx([0x02])),
      );
      expect(step.action, FinalUnlockTrackAction.failed);
      expect(t.successfulCommands, 0);
    });
  });
}
