import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/protocol/final_unlock_response_parser.dart';
import 'package:need_for_needs/core/ble/protocol/parsed_ble_response.dart';

Uint8List _rx(List<int> bytes) => Uint8List.fromList(bytes);

Uint8List liveLike({required int b0, required int b1, required int b4}) {
  return _rx([
    b0, b1, 0x00, 0x00, b4,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ]);
}

/// Collect UI shows Try Again only after a finished failed attempt
/// (`_error` or `_commandSent`), never while busy/waiting, never on success.
bool tryAgainVisible({
  required bool unlockSuccess,
  required bool opened,
  String? error,
  bool commandSent = false,
  bool busy = false,
}) {
  if (opened || unlockSuccess || busy) return false;
  return error != null || commandSent;
}

void main() {
  group('FinalUnlockResponseParser — 0x02 never error', () {
    test('[0]==0x02 pending → isError false', () {
      final p = FinalUnlockResponseParser.parse(
        liveLike(b0: 0x02, b1: 0x01, b4: 0xA1),
      );
      expect(p.isError, isFalse);
      expect(p.isPending, isTrue);
      expect(p.isSuccess, isFalse);
    });

    test('[0]==0x02 complete A1 → isError false', () {
      final p = FinalUnlockResponseParser.parse(
        liveLike(b0: 0x02, b1: 0x00, b4: 0xA1),
      );
      expect(p.isError, isFalse);
      expect(p.isSuccess, isTrue);
    });

    test('[0]==0x04 → isError true', () {
      final p = FinalUnlockResponseParser.parse(
        liveLike(b0: 0x04, b1: 0x00, b4: 0x00),
      );
      expect(p.isError, isTrue);
      expect(p.isSuccess, isFalse);
    });
  });

  group('FinalUnlockResponseTracker — false Try Again regression', () {
    test('TEST1: 2 cmds pending→complete ×2 → SUCCESS TryAgain=false', () {
      final t = FinalUnlockResponseTracker(expectedCommands: 2);

      expect(
        t
            .apply(FinalUnlockResponseParser.parse(
              liveLike(b0: 0x02, b1: 0x01, b4: 0xA1),
            ))
            .action,
        FinalUnlockTrackAction.continueWaiting,
      );
      expect(
        t
            .apply(FinalUnlockResponseParser.parse(
              liveLike(b0: 0x02, b1: 0x00, b4: 0xA1),
            ))
            .action,
        FinalUnlockTrackAction.progress,
      );
      expect(
        t
            .apply(FinalUnlockResponseParser.parse(
              liveLike(b0: 0x02, b1: 0x01, b4: 0xA1),
            ))
            .action,
        FinalUnlockTrackAction.continueWaiting,
      );
      final last = t.apply(
        FinalUnlockResponseParser.parse(
          liveLike(b0: 0x02, b1: 0x00, b4: 0xA1),
        ),
      );

      expect(last.action, FinalUnlockTrackAction.allSucceeded);
      expect(last.isOverallSuccess, isTrue);
      expect(t.successfulCommands, 2);
      expect(t.errorCount, 0);

      final unlock = UnlockResult.ok(stage: 'complete');
      expect(
        tryAgainVisible(
          unlockSuccess: unlock.success,
          opened: unlock.success,
        ),
        isFalse,
      );
    });

    test('TEST2: success then 0x04 → FAILURE TryAgain=true', () {
      final t = FinalUnlockResponseTracker(expectedCommands: 2);
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
      expect(t.successfulCommands, 1);
      expect(t.errorCount, 1);

      final unlock = UnlockResult.fail(
        stage: 'open',
        message: 'Locker couldn\'t be opened.',
      );
      expect(
        tryAgainVisible(
          unlockSuccess: unlock.success,
          opened: false,
          error: unlock.message,
        ),
        isTrue,
      );
    });

    test('TEST3: success then pending → wait, NOT error, TryAgain=false', () {
      final t = FinalUnlockResponseTracker(expectedCommands: 2);
      expect(
        t
            .apply(FinalUnlockResponseParser.parse(
              liveLike(b0: 0x02, b1: 0x00, b4: 0xA1),
            ))
            .action,
        FinalUnlockTrackAction.progress,
      );
      final pending = t.apply(
        FinalUnlockResponseParser.parse(
          liveLike(b0: 0x02, b1: 0x01, b4: 0xA1),
        ),
      );
      expect(pending.action, FinalUnlockTrackAction.continueWaiting);
      expect(t.errorCount, 0);
      expect(t.isOverallSuccess, isFalse);
      expect(pending.parsed.isError, isFalse);
      // Still waiting for command 2 — busy Collect UI, not Try Again.
      expect(
        tryAgainVisible(
          unlockSuccess: false,
          opened: false,
          error: null,
          commandSent: false,
          busy: true,
        ),
        isFalse,
      );
    });

    test('TEST4: two completes → SUCCESS', () {
      final t = FinalUnlockResponseTracker(expectedCommands: 2);
      t.apply(
        FinalUnlockResponseParser.parse(
          liveLike(b0: 0x02, b1: 0x00, b4: 0xA1),
        ),
      );
      final last = t.apply(
        FinalUnlockResponseParser.parse(
          liveLike(b0: 0x02, b1: 0x00, b4: 0xA1),
        ),
      );
      expect(last.action, FinalUnlockTrackAction.allSucceeded);
      expect(t.errorCount, 0);
      expect(t.successfulCommands, 2);
    });

    test('0x02 complete without A1 continues waiting — not failed', () {
      final t = FinalUnlockResponseTracker(expectedCommands: 1);
      final step = t.apply(
        FinalUnlockResponseParser.parse(
          liveLike(b0: 0x02, b1: 0x00, b4: 0x00),
        ),
      );
      expect(step.action, FinalUnlockTrackAction.continueWaiting);
      expect(t.errorCount, 0);
      expect(step.parsed.isError, isFalse);
    });

    test('short/malformed does not become MCU error', () {
      final t = FinalUnlockResponseTracker(expectedCommands: 1);
      final step = t.apply(
        FinalUnlockResponseParser.parse(_rx([0x02])),
      );
      expect(step.action, FinalUnlockTrackAction.continueWaiting);
      expect(t.errorCount, 0);
    });
  });
}
