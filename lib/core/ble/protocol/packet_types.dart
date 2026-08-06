/// Phase 10 protocol constants ported to Dart (design-compatible).
library;

/// Packet type names and wire codes.
enum BlePacketType {
  ping(0x01),
  pong(0x02),
  auth(0x10),
  authAck(0x11),
  openBox(0x20),
  openAck(0x21),
  status(0x30),
  statusResponse(0x31),
  error(0x40),
  heartbeat(0x50),
  disconnect(0x60);

  const BlePacketType(this.code);
  final int code;

  static BlePacketType? fromCode(int code) {
    for (final t in BlePacketType.values) {
      if (t.code == code) return t;
    }
    return null;
  }

  String get wireName {
    switch (this) {
      case BlePacketType.ping:
        return 'PING';
      case BlePacketType.pong:
        return 'PONG';
      case BlePacketType.auth:
        return 'AUTH';
      case BlePacketType.authAck:
        return 'AUTH_ACK';
      case BlePacketType.openBox:
        return 'OPEN_BOX';
      case BlePacketType.openAck:
        return 'OPEN_ACK';
      case BlePacketType.status:
        return 'STATUS';
      case BlePacketType.statusResponse:
        return 'STATUS_RESPONSE';
      case BlePacketType.error:
        return 'ERROR';
      case BlePacketType.heartbeat:
        return 'HEARTBEAT';
      case BlePacketType.disconnect:
        return 'DISCONNECT';
    }
  }

  static BlePacketType? fromWireName(String name) {
    final upper = name.toUpperCase();
    for (final t in BlePacketType.values) {
      if (t.wireName == upper) return t;
    }
    return null;
  }
}

/// Application error codes from Phase 10.
enum BleErrorCode {
  invalidToken(1001, 'INVALID_TOKEN', retryable: false),
  invalidBox(1002, 'INVALID_BOX', retryable: false),
  lockerBusy(1003, 'LOCKER_BUSY', retryable: true),
  doorAlreadyOpen(1004, 'DOOR_ALREADY_OPEN', retryable: false),
  bleTimeout(1005, 'BLE_TIMEOUT', retryable: true),
  unknownCommand(1006, 'UNKNOWN_COMMAND', retryable: false),
  crcFailed(1007, 'CRC_FAILED', retryable: true);

  const BleErrorCode(this.code, this.wireName, {required this.retryable});
  final int code;
  final String wireName;
  final bool retryable;

  static BleErrorCode? fromCode(int code) {
    for (final e in BleErrorCode.values) {
      if (e.code == code) return e;
    }
    return null;
  }
}

/// Field size limits (bytes) — Phase 10 `LIMITS`.
abstract final class BleProtocolLimits {
  static const int orderId = 40;
  static const int lockerId = 32;
  static const int boxId = 32;
  static const int collectionToken = 128;
  static const int payload = 200;
  static const int maxFrameBytes = 512;
  static const int protocolVersion = 1;
}
