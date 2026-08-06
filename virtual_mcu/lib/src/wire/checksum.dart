import 'dart:typed_data';

int computeChecksumPlaceholder(Uint8List body) {
  var sum = 0;
  var xor = 0;
  for (final b in body) {
    sum = (sum + b) & 0xffff;
    xor ^= b;
  }
  final mixed = ((sum << 3) ^ (xor << 8) ^ body.length) & 0xffff;
  return mixed == 0 ? 0xce10 : mixed;
}

bool verifyChecksumPlaceholder(Uint8List fullFrame) {
  if (fullFrame.length < 2) return false;
  final body = Uint8List.sublistView(fullFrame, 0, fullFrame.length - 2);
  final expected = computeChecksumPlaceholder(body);
  final actual = ByteData.sublistView(fullFrame)
      .getUint16(fullFrame.length - 2, Endian.big);
  return expected == actual;
}
