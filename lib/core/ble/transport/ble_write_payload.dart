import 'dart:typed_data';

/// Deterministic BLE write payload preparation (no packet-format changes).
///
/// Ensures fresh buffers and, when ATT payload is too small for one write,
/// splits bytes into ordered chunks whose concatenation equals [packet].
abstract final class BleWritePayload {
  /// ATT application payload size from negotiated MTU (`mtu - 3`).
  static int maxPayloadForMtu(int? mtu) {
    if (mtu == null || mtu <= 3) return 20;
    return mtu - 3;
  }

  /// Fresh copy of [packet] — never reuse caller buffers across writes.
  static Uint8List copyOf(Uint8List packet) => Uint8List.fromList(packet);

  /// Split [packet] into MTU-safe chunks. Single chunk when it fits.
  ///
  /// Each chunk is a **new** [Uint8List]. Concatenation always equals [packet].
  static List<Uint8List> splitForAttPayload(
    Uint8List packet, {
    required int maxPayload,
  }) {
    if (maxPayload < 1) {
      throw ArgumentError('maxPayload must be >= 1, got $maxPayload');
    }
    final original = copyOf(packet);
    if (original.length <= maxPayload) {
      return [original];
    }
    final chunks = <Uint8List>[];
    for (var offset = 0; offset < original.length; offset += maxPayload) {
      final end = offset + maxPayload < original.length
          ? offset + maxPayload
          : original.length;
      chunks.add(Uint8List.fromList(original.sublist(offset, end)));
    }
    final rebuilt = concatenate(chunks);
    if (!_bytesEqual(rebuilt, original)) {
      throw StateError(
        'BLE chunk reconstruction mismatch: '
        'original=${_hex(original)} rebuilt=${_hex(rebuilt)}',
      );
    }
    return chunks;
  }

  static Uint8List concatenate(List<Uint8List> chunks) {
    final total = chunks.fold<int>(0, (sum, c) => sum + c.length);
    final out = Uint8List(total);
    var o = 0;
    for (final c in chunks) {
      out.setRange(o, o + c.length, c);
      o += c.length;
    }
    return out;
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String hex(Uint8List bytes) => _hex(bytes);

  static String _hex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
}
