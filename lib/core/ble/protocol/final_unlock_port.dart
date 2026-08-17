import 'dart:typed_data';

import 'box_unlock_mask.dart';

/// FINAL firmware Port field (4-byte box unlock bitmap).
///
/// Mapping matches [BoxUnlockMask]: Box N → bit (N − 1), boxes 1–32.
/// Wire byte order is isolated here so endianness can change in one place.
abstract final class FinalUnlockPort {
  static const int encodedLength = 4;
  static const int minBox = BoxUnlockMask.minBox;
  static const int maxBox = BoxUnlockMask.maxBox;

  /// Build 32-bit unlock mask from the **current order's** box numbers only.
  static int buildPortMask(List<int> boxNumbers) =>
      BoxUnlockMask.buildBoxUnlockMask(boxNumbers);

  /// Encode [mask] to exactly 4 Port bytes (little-endian, firmware-confirmed).
  ///
  /// Example: `0x00000015` → `15 00 00 00`
  /// Example: `0x80000015` → `15 00 00 80`
  static Uint8List encodePort32(int mask) {
    final m = mask & 0xFFFFFFFF;
    final out = Uint8List(encodedLength);
    ByteData.sublistView(out).setUint32(0, m, Endian.little);
    assert(out.length == encodedLength);
    return out;
  }

  static String maskHex(int mask) => BoxUnlockMask.maskHex(mask);

  static String encodedHex(Uint8List bytes) => BoxUnlockMask.encodedHex(bytes);
}
