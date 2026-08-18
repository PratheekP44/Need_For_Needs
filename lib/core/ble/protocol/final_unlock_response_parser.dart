import 'dart:typed_data';

import '../transport/ble_log.dart';

/// Confirmed FinalUnlock / LKRM RX response kinds (Phase 44B / 44B-FIX).
///
/// Values from live capture + user-confirmed firmware behavior only.
enum FinalUnlockRxType {
  commandResponse,
  error,
  unknown,
}

enum FinalUnlockRxCommandState {
  pending,
  complete,
  unknown,
}

enum FinalUnlockRxResult {
  unlocked,
  processing,
  unknown,
  none,
}

/// Pure parse of one MCU notification for the FinalUnlock Collect path.
class FinalUnlockParsedResponse {
  const FinalUnlockParsedResponse({
    required this.raw,
    required this.rawHex,
    required this.length,
    required this.validLength,
    required this.type,
    required this.commandState,
    required this.result,
    this.byte0,
    this.byte1,
    this.byte4,
  });

  final Uint8List raw;
  final String rawHex;
  final int length;
  final bool validLength;
  final FinalUnlockRxType type;
  final FinalUnlockRxCommandState commandState;
  final FinalUnlockRxResult result;
  final int? byte0;
  final int? byte1;
  final int? byte4;

  /// Pending / waiting — not a successful unlock command.
  bool get isPending =>
      validLength &&
      type == FinalUnlockRxType.commandResponse &&
      commandState == FinalUnlockRxCommandState.pending;

  /// Confirmed unlock complete for one command.
  /// Requires [0]==0x02 AND [1]==0x00 AND [4]==0xA1.
  bool get isSuccess =>
      validLength &&
      type == FinalUnlockRxType.commandResponse &&
      commandState == FinalUnlockRxCommandState.complete &&
      result == FinalUnlockRxResult.unlocked;

  /// ONLY explicit MCU error: [0] == 0x04.
  /// A [0] == 0x02 response is NEVER an error (pending, complete, or otherwise).
  bool get isError =>
      validLength &&
      byte0 == FinalUnlockResponseParser.typeError &&
      type == FinalUnlockRxType.error;

  bool get isInvalid => !validLength;

  /// Command-response ([0]==0x02) that is not yet a counted success.
  /// Includes pending and non-A1 complete — keep waiting, never error.
  bool get isCommandResponseNonError =>
      validLength && byte0 == FinalUnlockResponseParser.typeCommandResponse;

  bool get isUnknown =>
      validLength &&
      !isPending &&
      !isSuccess &&
      !isError;

  void logDeveloper({int? notificationIndex, int? commandSuccessCount, int? errorCount}) {
    final n = notificationIndex ?? 0;
    BleLog.d('── COLLECT RESPONSE #$n (Phase 44B) ──');
    BleLog.d('Length: $length');
    BleLog.d('HEX: $rawHex');
    BleLog.d(
      'DEC: [${raw.map((b) => b.toString()).join(', ')}]',
    );
    BleLog.d('Type: ${_typeLabel()}');
    BleLog.d('State: ${_stateLabel()}');
    BleLog.d('Result: ${_resultLabel()}');
    BleLog.d('isError: $isError (only true when [0]==0x04)');
    if (commandSuccessCount != null) {
      BleLog.d('Successful commands so far: $commandSuccessCount');
    }
    if (errorCount != null) {
      BleLog.d('Error count so far: $errorCount');
    }
    BleLog.d('── end COLLECT RESPONSE #$n ──');
  }

  String _typeLabel() {
    switch (type) {
      case FinalUnlockRxType.commandResponse:
        return 'COMMAND_RESPONSE';
      case FinalUnlockRxType.error:
        return 'ERROR';
      case FinalUnlockRxType.unknown:
        return 'UNKNOWN';
    }
  }

  String _stateLabel() {
    if (isInvalid) return 'INVALID';
    switch (commandState) {
      case FinalUnlockRxCommandState.pending:
        return 'PENDING';
      case FinalUnlockRxCommandState.complete:
        return 'COMPLETE';
      case FinalUnlockRxCommandState.unknown:
        return 'UNKNOWN';
    }
  }

  String _resultLabel() {
    if (isPending) return 'PROCESSING';
    if (isSuccess) return 'UNLOCKED';
    if (isError) return 'ERROR';
    if (isInvalid) return 'INVALID';
    return 'UNKNOWN';
  }
}

/// Phase 44B — authoritative FinalUnlock RX parser (confirmed live format).
///
/// Does not invent error/sub-error maps. Sync bytes [2],[3] ignored.
class FinalUnlockResponseParser {
  FinalUnlockResponseParser._();

  static const int minLength = 5;
  static const int typeCommandResponse = 0x02;
  static const int typeError = 0x04;
  static const int statePending = 0x01;
  static const int stateComplete = 0x00;
  static const int resultUnlocked = 0xA1;

  static FinalUnlockParsedResponse parse(Uint8List raw) {
    final copy = Uint8List.fromList(raw);
    final hex = copy
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');

    if (copy.length < minLength) {
      return FinalUnlockParsedResponse(
        raw: copy,
        rawHex: hex,
        length: copy.length,
        validLength: false,
        type: FinalUnlockRxType.unknown,
        commandState: FinalUnlockRxCommandState.unknown,
        result: FinalUnlockRxResult.none,
        byte0: copy.isNotEmpty ? copy[0] : null,
        byte1: copy.length >= 2 ? copy[1] : null,
        byte4: copy.length >= 5 ? copy[4] : null,
      );
    }

    final b0 = copy[0];
    final b1 = copy[1];
    // Bytes 2–3: sync — ignored by design.
    final b4 = copy[4];

    FinalUnlockRxType type;
    if (b0 == typeCommandResponse) {
      type = FinalUnlockRxType.commandResponse;
    } else if (b0 == typeError) {
      type = FinalUnlockRxType.error;
    } else {
      type = FinalUnlockRxType.unknown;
    }

    FinalUnlockRxCommandState commandState;
    if (type == FinalUnlockRxType.commandResponse) {
      if (b1 == statePending) {
        commandState = FinalUnlockRxCommandState.pending;
      } else if (b1 == stateComplete) {
        commandState = FinalUnlockRxCommandState.complete;
      } else {
        commandState = FinalUnlockRxCommandState.unknown;
      }
    } else {
      commandState = FinalUnlockRxCommandState.unknown;
    }

    FinalUnlockRxResult result;
    if (type == FinalUnlockRxType.commandResponse &&
        commandState == FinalUnlockRxCommandState.pending) {
      result = FinalUnlockRxResult.processing;
    } else if (type == FinalUnlockRxType.commandResponse &&
        commandState == FinalUnlockRxCommandState.complete &&
        b4 == resultUnlocked) {
      result = FinalUnlockRxResult.unlocked;
    } else if (type == FinalUnlockRxType.commandResponse &&
        commandState == FinalUnlockRxCommandState.complete) {
      // Complete but not 0xA1 — keep waiting; NOT an MCU error.
      result = FinalUnlockRxResult.unknown;
    } else {
      result = FinalUnlockRxResult.unknown;
    }

    return FinalUnlockParsedResponse(
      raw: copy,
      rawHex: hex,
      length: copy.length,
      validLength: true,
      type: type,
      commandState: commandState,
      result: result,
      byte0: b0,
      byte1: b1,
      byte4: b4,
    );
  }
}

/// Aggregates notifications for one Collect attempt (one TX, N unlocks).
enum FinalUnlockTrackAction {
  /// Keep waiting for another notification (pending / non-error incomplete).
  continueWaiting,

  /// One unlock command completed; still need more.
  progress,

  /// All expected unlock commands completed and errorCount == 0.
  allSucceeded,

  /// Hard failure: ONLY an MCU [0]==0x04 error (or explicit invalid empty).
  failed,
}

class FinalUnlockTrackStep {
  const FinalUnlockTrackStep({
    required this.action,
    required this.parsed,
    required this.successfulCommands,
    required this.expectedCommands,
    required this.errorCount,
    required this.notificationIndex,
    this.failedNotificationIndex,
  });

  final FinalUnlockTrackAction action;
  final FinalUnlockParsedResponse parsed;
  final int successfulCommands;
  final int expectedCommands;
  final int errorCount;
  final int notificationIndex;
  final int? failedNotificationIndex;

  bool get isOverallSuccess =>
      action == FinalUnlockTrackAction.allSucceeded &&
      successfulCommands >= expectedCommands &&
      errorCount == 0;
}

/// Counts completed unlocks; pending / non-error 0x02 never increments errors.
class FinalUnlockResponseTracker {
  FinalUnlockResponseTracker({required this.expectedCommands})
      : assert(expectedCommands >= 1);

  final int expectedCommands;
  int successfulCommands = 0;
  int errorCount = 0;
  int notificationIndex = 0;
  int? failedNotificationIndex;

  bool get isOverallSuccess =>
      successfulCommands >= expectedCommands && errorCount == 0;

  FinalUnlockTrackStep apply(FinalUnlockParsedResponse parsed) {
    notificationIndex += 1;
    parsed.logDeveloper(
      notificationIndex: notificationIndex,
      commandSuccessCount: successfulCommands,
      errorCount: errorCount,
    );

    // ── FIRST: [0] == 0x04 → MCU ERROR only ──
    if (parsed.isError) {
      errorCount += 1;
      failedNotificationIndex = notificationIndex;
      BleLog.e(
        '[FinalUnlockTracker] COMMAND ERROR [0]==0x04 '
        'at response #$notificationIndex HEX=${parsed.rawHex}',
      );
      return FinalUnlockTrackStep(
        action: FinalUnlockTrackAction.failed,
        parsed: parsed,
        successfulCommands: successfulCommands,
        expectedCommands: expectedCommands,
        errorCount: errorCount,
        notificationIndex: notificationIndex,
        failedNotificationIndex: failedNotificationIndex,
      );
    }

    // ── [0] == 0x02 → NEVER an error ──
    if (parsed.isCommandResponseNonError ||
        parsed.byte0 == FinalUnlockResponseParser.typeCommandResponse) {
      if (parsed.isPending) {
        return FinalUnlockTrackStep(
          action: FinalUnlockTrackAction.continueWaiting,
          parsed: parsed,
          successfulCommands: successfulCommands,
          expectedCommands: expectedCommands,
          errorCount: errorCount,
          notificationIndex: notificationIndex,
        );
      }

      if (parsed.isSuccess) {
        successfulCommands += 1;
        BleLog.d(
          '[FinalUnlockTracker] unlock complete '
          '$successfulCommands/$expectedCommands errors=$errorCount',
        );
        if (isOverallSuccess) {
          return FinalUnlockTrackStep(
            action: FinalUnlockTrackAction.allSucceeded,
            parsed: parsed,
            successfulCommands: successfulCommands,
            expectedCommands: expectedCommands,
            errorCount: errorCount,
            notificationIndex: notificationIndex,
          );
        }
        return FinalUnlockTrackStep(
          action: FinalUnlockTrackAction.progress,
          parsed: parsed,
          successfulCommands: successfulCommands,
          expectedCommands: expectedCommands,
          errorCount: errorCount,
          notificationIndex: notificationIndex,
        );
      }

      // [0]==0x02 but not yet counted success (e.g. complete without A1,
      // unknown [1]). Keep waiting — MUST NOT become Try Again / failed.
      BleLog.d(
        '[FinalUnlockTracker] [0]==0x02 non-final — continue waiting '
        '(not an error) HEX=${parsed.rawHex}',
      );
      return FinalUnlockTrackStep(
        action: FinalUnlockTrackAction.continueWaiting,
        parsed: parsed,
        successfulCommands: successfulCommands,
        expectedCommands: expectedCommands,
        errorCount: errorCount,
        notificationIndex: notificationIndex,
      );
    }

    // Other non-0x04 bytes (and short frames): keep waiting; not MCU error.
    // Legitimate timeout elsewhere ends the attempt if responses never arrive.
    BleLog.d(
      '[FinalUnlockTracker] non-error unrecognized notify — continue waiting '
      'HEX=${parsed.rawHex}',
    );
    return FinalUnlockTrackStep(
      action: FinalUnlockTrackAction.continueWaiting,
      parsed: parsed,
      successfulCommands: successfulCommands,
      expectedCommands: expectedCommands,
      errorCount: errorCount,
      notificationIndex: notificationIndex,
    );
  }
}
