import 'dart:typed_data';

/// Firmware multi-box unlock bitmap helpers (Phase 20).
///
/// Professor-confirmed mapping:
/// - Box N → bit index (N − 1)
/// - Bit 0 = Box 1 … Bit 31 = Box 32
/// - Bit value 1 = unlock, 0 = leave closed
///
/// These helpers only build the 32-bit mask and encode it to 4 bytes.
/// They do not know packet offsets — [RealPacketBuilder] places the bytes.
abstract final class BoxUnlockMask {
  static const int minBox = 1;
  static const int maxBox = 32;
  static const int encodedLength = 4;

  /// Build a 32-bit unlock mask from physical box numbers (1–32).
  ///
  /// Duplicates are ignored. Empty / out-of-range lists throw [ArgumentError].
  /// Uses unsigned 32-bit semantics (`& 0xFFFFFFFF`) so Box 32 (bit 31) is safe.
  static int buildBoxUnlockMask(List<int> boxNumbers) {
    if (boxNumbers.isEmpty) {
      throw ArgumentError('boxNumbers must not be empty');
    }

    var mask = 0;
    final seen = <int>{};
    for (final raw in boxNumbers) {
      final box = raw;
      if (box < minBox || box > maxBox) {
        throw ArgumentError(
          'boxNumber $box out of range ($minBox–$maxBox)',
        );
      }
      if (!seen.add(box)) continue; // deduplicate

      final bitIndex = box - 1;
      // Shift as unsigned: Box 32 → bit 31 → 0x80000000
      mask |= (1 << bitIndex);
    }

    return mask & 0xFFFFFFFF;
  }

  /// Encode a 32-bit mask into exactly four packet bytes.
  ///
  /// **Byte-order assumption (isolated here — only place that defines it):**
  /// Little-endian (LSB first):
  /// - Byte[0] of this array = bits 0–7   → Boxes 1–8
  /// - Byte[1] = bits 8–15  → Boxes 9–16
  /// - Byte[2] = bits 16–23 → Boxes 17–24
  /// - Byte[3] = bits 24–31 → Boxes 25–32
  ///
  /// Professor confirmed bit mapping (Box 1 = bit 0) but not wire endianness.
  /// If hardware expects big-endian, change **only** this function.
  static Uint8List encodeBoxMask32(int mask) {
    final m = mask & 0xFFFFFFFF;
    final out = Uint8List(encodedLength);
    ByteData.sublistView(out).setUint32(0, m, Endian.little);
    assert(out.length == encodedLength);
    return out;
  }

  /// Hex string for logs: `0x80000015`.
  static String maskHex(int mask) =>
      '0x${(mask & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';

  /// Space-separated hex of four encoded bytes.
  static String encodedHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
}
