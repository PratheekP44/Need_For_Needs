import 'dart:convert';
import 'dart:typed_data';

import 'checksum.dart';
import 'packet_types.dart';

/// Decoded Phase 10–compatible frame.
class McuFrame {
  McuFrame({
    required this.protocolVersion,
    required this.type,
    required this.sequenceNumber,
    required this.timestamp,
    required this.orderId,
    required this.lockerId,
    required this.boxId,
    required this.collectionToken,
    required this.payload,
    this.checksum = 0,
  });

  final int protocolVersion;
  final McuPacketType type;
  final int sequenceNumber;
  final int timestamp;
  final String orderId;
  final String lockerId;
  final String boxId;
  final String collectionToken;
  final Uint8List payload;
  int checksum;

  Map<String, Object?>? payloadJson() {
    if (payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(payload));
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return null;
  }
}

class FrameCodec {
  const FrameCodec();

  Uint8List encode({
    required McuPacketType type,
    required int sequenceNumber,
    int timestamp = 0,
    String orderId = '',
    String lockerId = '',
    String boxId = '',
    String collectionToken = '',
    Uint8List? payload,
    bool corruptChecksum = false,
  }) {
    final bodyPayload = payload ?? Uint8List(0);
    final builder = BytesBuilder(copy: false);
    final header = ByteData(8);
    header.setUint8(0, McuLimits.protocolVersion);
    header.setUint8(1, type.code);
    header.setUint16(2, sequenceNumber & 0xffff, Endian.big);
    header.setUint32(
      4,
      (timestamp == 0
              ? DateTime.now().millisecondsSinceEpoch ~/ 1000
              : timestamp) &
          0xffffffff,
      Endian.big,
    );
    builder.add(header.buffer.asUint8List());
    _writeString(builder, orderId, McuLimits.orderId);
    _writeString(builder, lockerId, McuLimits.lockerId);
    _writeString(builder, boxId, McuLimits.boxId);
    _writeString(builder, collectionToken, McuLimits.collectionToken);
    final plen = ByteData(2)..setUint16(0, bodyPayload.length, Endian.big);
    builder.add(plen.buffer.asUint8List());
    if (bodyPayload.isNotEmpty) builder.add(bodyPayload);

    final body = builder.toBytes();
    var checksum = computeChecksumPlaceholder(body);
    if (corruptChecksum) checksum ^= 0xffff;
    final frame = Uint8List(body.length + 2);
    frame.setAll(0, body);
    ByteData.sublistView(frame).setUint16(body.length, checksum, Endian.big);
    return frame;
  }

  McuFrame decode(Uint8List frame) {
    if (frame.length < 10) {
      throw const FormatException('Frame too short');
    }
    if (!verifyChecksumPlaceholder(frame)) {
      throw const FormatException('CRC_FAILED');
    }
    final body = Uint8List.sublistView(frame, 0, frame.length - 2);
    var offset = 0;
    final version = body[offset++];
    final typeCode = body[offset++];
    final seq = ByteData.sublistView(body).getUint16(offset, Endian.big);
    offset += 2;
    final ts = ByteData.sublistView(body).getUint32(offset, Endian.big);
    offset += 4;
    final type = McuPacketType.fromCode(typeCode);
    if (type == null) {
      throw FormatException('UNKNOWN_COMMAND:$typeCode');
    }
    if (version != McuLimits.protocolVersion) {
      throw FormatException('bad protocolVersion:$version');
    }
    final order = _readString(body, offset, McuLimits.orderId);
    offset = order.offset;
    final locker = _readString(body, offset, McuLimits.lockerId);
    offset = locker.offset;
    final box = _readString(body, offset, McuLimits.boxId);
    offset = box.offset;
    final token = _readString(body, offset, McuLimits.collectionToken);
    offset = token.offset;
    final payloadLen =
        ByteData.sublistView(body).getUint16(offset, Endian.big);
    offset += 2;
    final payload =
        Uint8List.fromList(body.sublist(offset, offset + payloadLen));
    final checksum =
        ByteData.sublistView(frame).getUint16(frame.length - 2, Endian.big);
    return McuFrame(
      protocolVersion: version,
      type: type,
      sequenceNumber: seq,
      timestamp: ts,
      orderId: order.value,
      lockerId: locker.value,
      boxId: box.value,
      collectionToken: token.value,
      payload: payload,
      checksum: checksum,
    );
  }

  Uint8List jsonPayload(Map<String, Object?> map) =>
      Uint8List.fromList(utf8.encode(jsonEncode(map)));

  void _writeString(BytesBuilder b, String value, int max) {
    final raw = Uint8List.fromList(utf8.encode(value));
    if (raw.length > max) {
      throw FormatException('field exceeds $max');
    }
    b.addByte(raw.length);
    if (raw.isNotEmpty) b.add(raw);
  }

  ({String value, int offset}) _readString(Uint8List body, int offset, int max) {
    final len = body[offset++];
    if (len > max || offset + len > body.length) {
      throw const FormatException('bad string');
    }
    final value = utf8.decode(body.sublist(offset, offset + len));
    return (value: value, offset: offset + len);
  }
}
