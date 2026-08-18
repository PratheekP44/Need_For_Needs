import 'dart:typed_data';

import '../transport/ble_log.dart';

/// Phase 44A — observation-only decode of BLE notification bytes.
///
/// Does **not** define firmware protocol authority. Only logs raw bytes and
/// labels a few user-supplied *candidate* fields when present.
///
/// Official error / sub-error offsets and mappings are intentionally absent.
class BleResponseObservation {
  const BleResponseObservation({
    required this.length,
    required this.bytesDec,
    required this.bytesHex,
    this.sequence,
    this.byte0,
    this.byte1,
    this.byte4,
    this.remainingAfterIndex4 = const [],
    this.byte0CandidateNote,
    this.pendingCandidateNote,
    this.lockerStateCandidateNote,
  });

  final int length;
  final List<int> bytesDec;
  final String bytesHex;
  final int? sequence;
  final int? byte0;
  final int? byte1;
  final int? byte4;
  final List<int> remainingAfterIndex4;
  final String? byte0CandidateNote;
  final String? pendingCandidateNote;
  final String? lockerStateCandidateNote;

  /// Inspect [raw] without mutating it. Returns an immutable snapshot.
  static BleResponseObservation inspect(
    Uint8List raw, {
    int? sequence,
  }) {
    final copy = List<int>.unmodifiable(List<int>.from(raw));
    final hex = copy
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');

    int? b0;
    int? b1;
    int? b4;
    String? b0Note;
    String? pendingNote;
    String? lockerNote;
    var remaining = const <int>[];

    if (copy.isNotEmpty) {
      b0 = copy[0];
      if (b0 == 0x02) {
        b0Note = 'Command Response (confirmed)';
      } else if (b0 == 0x04) {
        b0Note = 'Error (confirmed type only; no sub-error map)';
      } else {
        b0Note = 'unknown (no mapping)';
      }
    }
    if (copy.length >= 2) {
      b1 = copy[1];
      if (b1 == 1) {
        pendingNote = 'YES (confirmed)';
      } else if (b1 == 0) {
        pendingNote = 'NO / DONE (confirmed)';
      } else {
        pendingNote = 'unknown (no mapping)';
      }
    }
    if (copy.length >= 5) {
      b4 = copy[4];
      if (b4 == 0xA1) {
        lockerNote = 'UNLOCKED candidate when complete (confirmed 0xA1)';
      } else {
        lockerNote = 'unknown (no mapping)';
      }
      if (copy.length > 5) {
        remaining = List<int>.unmodifiable(copy.sublist(5));
      }
    }

    return BleResponseObservation(
      length: copy.length,
      bytesDec: copy,
      bytesHex: hex,
      sequence: sequence,
      byte0: b0,
      byte1: b1,
      byte4: b4,
      remainingAfterIndex4: remaining,
      byte0CandidateNote: b0Note,
      pendingCandidateNote: pendingNote,
      lockerStateCandidateNote: lockerNote,
    );
  }

  /// Developer console only — never for user UI.
  void log() {
    final header = sequence != null
        ? 'COLLECT RESPONSE #$sequence'
        : 'BLE RESPONSE';
    BleLog.d('── $header (Phase 44A observation) ──');
    BleLog.d('Length: $length');
    BleLog.d('HEX: $bytesHex');
    BleLog.d('DEC: $bytesDec');
    if (byte0 != null) {
      BleLog.d(
        'Command Response candidate [0]: '
        '0x${byte0!.toRadixString(16).padLeft(2, '0')} '
        '(${byte0CandidateNote ?? 'observed'})',
      );
    }
    if (byte1 != null) {
      BleLog.d(
        'Pending candidate [1]: '
        '0x${byte1!.toRadixString(16).padLeft(2, '0')} '
        '→ Observed pending candidate: '
        '${pendingCandidateNote ?? 'observed'}',
      );
    }
    if (byte4 != null) {
      BleLog.d(
        'Locker State candidate [4]: '
        '0x${byte4!.toRadixString(16).padLeft(2, '0')} '
        '→ Observed locker state candidate: '
        '${lockerStateCandidateNote ?? 'observed'}',
      );
    }
    if (remainingAfterIndex4.isNotEmpty) {
      final remHex = remainingAfterIndex4
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      BleLog.d(
        'Remaining bytes after [4] (no meaning assigned): '
        'HEX=$remHex DEC=$remainingAfterIndex4',
      );
    }
    BleLog.d('── end observation ──');
  }
}
