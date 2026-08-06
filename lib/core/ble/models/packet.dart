import 'dart:convert';

import '../protocol/packet_types.dart';
import 'packet_header.dart';
import 'packet_payload.dart';

/// Full logical BLE packet (header + payload + checksum).
class Packet {
  Packet({
    required this.header,
    required this.payload,
    this.checksum = 0,
  });

  factory Packet.build({
    required BlePacketType type,
    required int sequenceNumber,
    String orderId = '',
    String lockerId = '',
    String boxId = '',
    String collectionToken = '',
    PacketPayload? payload,
    int? timestamp,
    int protocolVersion = BleProtocolLimits.protocolVersion,
  }) {
    final body = payload ?? PacketPayload.empty();
    return Packet(
      header: PacketHeader(
        protocolVersion: protocolVersion,
        packetType: type,
        sequenceNumber: sequenceNumber,
        timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        orderId: orderId,
        lockerId: lockerId,
        boxId: boxId,
        collectionToken: collectionToken,
        payloadLength: body.length,
      ),
      payload: body,
    );
  }

  final PacketHeader header;
  final PacketPayload payload;
  int checksum;

  BlePacketType get packetType => header.packetType;

  List<String> validate() {
    final errors = <String>[];
    if (header.protocolVersion != BleProtocolLimits.protocolVersion) {
      errors.add('Unsupported protocolVersion: ${header.protocolVersion}');
    }
    if (header.sequenceNumber < 0 || header.sequenceNumber > 0xffff) {
      errors.add('sequenceNumber must be uint16');
    }
    if (header.timestamp < 0) {
      errors.add('timestamp must be non-negative');
    }
    void checkLen(String name, String value, int max) {
      final len = utf8.encode(value).length;
      if (len > max) errors.add('$name exceeds $max bytes');
    }

    checkLen('orderId', header.orderId, BleProtocolLimits.orderId);
    checkLen('lockerId', header.lockerId, BleProtocolLimits.lockerId);
    checkLen('boxId', header.boxId, BleProtocolLimits.boxId);
    checkLen(
      'collectionToken',
      header.collectionToken,
      BleProtocolLimits.collectionToken,
    );
    if (payload.length > BleProtocolLimits.payload) {
      errors.add('payload exceeds ${BleProtocolLimits.payload} bytes');
    }
    if (header.payloadLength != payload.length) {
      errors.add('payloadLength does not match payload');
    }
    return errors;
  }

  bool get isValid => validate().isEmpty;

  Map<String, Object?> toJson() => {
        ...header.toJson(),
        'payload': payload.asJsonMap() ??
            (payload.bytes.isEmpty
                ? ''
                : payload.bytes
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join()),
        'checksum': checksum,
      };
}
