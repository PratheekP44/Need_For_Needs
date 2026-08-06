import '../protocol/packet_types.dart';

/// Fixed header fields of a Campus Essentials BLE frame.
class PacketHeader {
  const PacketHeader({
    required this.protocolVersion,
    required this.packetType,
    required this.sequenceNumber,
    required this.timestamp,
    required this.orderId,
    required this.lockerId,
    required this.boxId,
    required this.collectionToken,
    required this.payloadLength,
  });

  final int protocolVersion;
  final BlePacketType packetType;
  final int sequenceNumber;
  final int timestamp;
  final String orderId;
  final String lockerId;
  final String boxId;
  final String collectionToken;
  final int payloadLength;

  PacketHeader copyWith({
    int? protocolVersion,
    BlePacketType? packetType,
    int? sequenceNumber,
    int? timestamp,
    String? orderId,
    String? lockerId,
    String? boxId,
    String? collectionToken,
    int? payloadLength,
  }) {
    return PacketHeader(
      protocolVersion: protocolVersion ?? this.protocolVersion,
      packetType: packetType ?? this.packetType,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      timestamp: timestamp ?? this.timestamp,
      orderId: orderId ?? this.orderId,
      lockerId: lockerId ?? this.lockerId,
      boxId: boxId ?? this.boxId,
      collectionToken: collectionToken ?? this.collectionToken,
      payloadLength: payloadLength ?? this.payloadLength,
    );
  }

  Map<String, Object?> toJson() => {
        'protocolVersion': protocolVersion,
        'packetType': packetType.wireName,
        'sequenceNumber': sequenceNumber,
        'timestamp': timestamp,
        'orderId': orderId,
        'lockerId': lockerId,
        'boxId': boxId,
        'collectionToken': collectionToken,
        'payloadLength': payloadLength,
      };
}
