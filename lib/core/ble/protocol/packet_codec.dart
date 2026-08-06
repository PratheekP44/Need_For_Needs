import 'dart:convert';
import 'dart:typed_data';

import '../models/packet.dart';
import '../models/packet_header.dart';
import '../models/packet_payload.dart';
import 'checksum.dart';
import 'packet_types.dart';

/// Encodes / decodes Phase 10 binary frames.
class PacketCodec {
  const PacketCodec();

  Uint8List encode(Packet packet) {
    final errors = packet.validate();
    if (errors.isNotEmpty) {
      throw FormatException('Invalid packet: ${errors.join('; ')}');
    }

    final builder = BytesBuilder(copy: false);
    final header = ByteData(8);
    header.setUint8(0, packet.header.protocolVersion);
    header.setUint8(1, packet.header.packetType.code);
    header.setUint16(2, packet.header.sequenceNumber & 0xffff, Endian.big);
    header.setUint32(4, packet.header.timestamp & 0xffffffff, Endian.big);
    builder.add(header.buffer.asUint8List());

    _writeString(builder, packet.header.orderId, BleProtocolLimits.orderId);
    _writeString(builder, packet.header.lockerId, BleProtocolLimits.lockerId);
    _writeString(builder, packet.header.boxId, BleProtocolLimits.boxId);
    _writeString(
      builder,
      packet.header.collectionToken,
      BleProtocolLimits.collectionToken,
    );

    final payloadLen = ByteData(2)
      ..setUint16(0, packet.payload.length, Endian.big);
    builder.add(payloadLen.buffer.asUint8List());
    if (packet.payload.length > 0) {
      builder.add(packet.payload.bytes);
    }

    final body = builder.toBytes();
    if (body.length + 2 > BleProtocolLimits.maxFrameBytes) {
      throw FormatException('Frame exceeds maxFrameBytes');
    }

    final checksum = computeChecksumPlaceholder(body);
    packet.checksum = checksum;
    final frame = Uint8List(body.length + 2);
    frame.setAll(0, body);
    ByteData.sublistView(frame).setUint16(body.length, checksum, Endian.big);
    return frame;
  }

  Packet decode(Uint8List frame) {
    if (frame.length < 10) {
      throw const FormatException('Frame too short');
    }
    if (frame.length > BleProtocolLimits.maxFrameBytes) {
      throw const FormatException('Frame too long');
    }
    if (!verifyChecksumPlaceholder(frame)) {
      throw const FormatException('CRC_FAILED: checksum placeholder mismatch');
    }

    final body = Uint8List.sublistView(frame, 0, frame.length - 2);
    var offset = 0;
    final protocolVersion = body[offset++];
    final typeCode = body[offset++];
    final sequenceNumber =
        ByteData.sublistView(body).getUint16(offset, Endian.big);
    offset += 2;
    final timestamp =
        ByteData.sublistView(body).getUint32(offset, Endian.big);
    offset += 4;

    if (protocolVersion != BleProtocolLimits.protocolVersion) {
      throw FormatException('Unsupported protocolVersion: $protocolVersion');
    }

    final type = BlePacketType.fromCode(typeCode);
    if (type == null) {
      throw FormatException(
        'UNKNOWN_COMMAND: packetType 0x${typeCode.toRadixString(16)}',
      );
    }

    final order = _readString(body, offset, BleProtocolLimits.orderId);
    offset = order.offset;
    final locker = _readString(body, offset, BleProtocolLimits.lockerId);
    offset = locker.offset;
    final box = _readString(body, offset, BleProtocolLimits.boxId);
    offset = box.offset;
    final token = _readString(body, offset, BleProtocolLimits.collectionToken);
    offset = token.offset;

    if (offset + 2 > body.length) {
      throw const FormatException('Missing payloadLength');
    }
    final payloadLength =
        ByteData.sublistView(body).getUint16(offset, Endian.big);
    offset += 2;
    if (payloadLength > BleProtocolLimits.payload) {
      throw const FormatException('payloadLength exceeds limit');
    }
    if (offset + payloadLength > body.length) {
      throw const FormatException('Truncated payload');
    }
    final payloadBytes =
        Uint8List.sublistView(body, offset, offset + payloadLength);
    offset += payloadLength;
    if (offset != body.length) {
      throw const FormatException('Trailing bytes in frame body');
    }

    final checksum =
        ByteData.sublistView(frame).getUint16(frame.length - 2, Endian.big);

    return Packet(
      header: PacketHeader(
        protocolVersion: protocolVersion,
        packetType: type,
        sequenceNumber: sequenceNumber,
        timestamp: timestamp,
        orderId: order.value,
        lockerId: locker.value,
        boxId: box.value,
        collectionToken: token.value,
        payloadLength: payloadLength,
      ),
      payload: PacketPayload.raw(Uint8List.fromList(payloadBytes)),
      checksum: checksum,
    );
  }

  void _writeString(BytesBuilder builder, String value, int maxLen) {
    final raw = Uint8List.fromList(utf8.encode(value));
    if (raw.length > maxLen) {
      throw FormatException('Field exceeds max length $maxLen');
    }
    if (raw.length > 255) {
      throw const FormatException('Length-prefixed string cannot exceed 255');
    }
    builder.addByte(raw.length);
    if (raw.isNotEmpty) builder.add(raw);
  }

  ({String value, int offset}) _readString(
    Uint8List body,
    int offset,
    int maxLen,
  ) {
    if (offset >= body.length) {
      throw const FormatException('Unexpected end while reading string length');
    }
    final len = body[offset];
    offset += 1;
    if (len > maxLen) {
      throw FormatException('String length $len exceeds max $maxLen');
    }
    if (offset + len > body.length) {
      throw const FormatException('Unexpected end while reading string');
    }
    final value = utf8.decode(body.sublist(offset, offset + len));
    return (value: value, offset: offset + len);
  }
}
