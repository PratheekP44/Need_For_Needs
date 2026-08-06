/// Wire packet types / error codes (Phase 10 compatible + sim extensions).
enum McuPacketType {
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

  const McuPacketType(this.code);
  final int code;

  static McuPacketType? fromCode(int code) {
    for (final t in McuPacketType.values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

/// Prefer explicit wire names for logging.
extension McuPacketTypeName on McuPacketType {
  String get label {
    switch (this) {
      case McuPacketType.ping:
        return 'PING';
      case McuPacketType.pong:
        return 'PONG';
      case McuPacketType.auth:
        return 'AUTH';
      case McuPacketType.authAck:
        return 'AUTH_ACK';
      case McuPacketType.openBox:
        return 'OPEN_BOX';
      case McuPacketType.openAck:
        return 'OPEN_ACK';
      case McuPacketType.status:
        return 'STATUS';
      case McuPacketType.statusResponse:
        return 'STATUS_RESPONSE';
      case McuPacketType.error:
        return 'ERROR';
      case McuPacketType.heartbeat:
        return 'HEARTBEAT';
      case McuPacketType.disconnect:
        return 'DISCONNECT';
    }
  }
}

enum McuErrorCode {
  invalidToken(1001, 'INVALID_TOKEN'),
  invalidBox(1002, 'INVALID_BOX'),
  lockerBusy(1003, 'LOCKER_BUSY'),
  doorAlreadyOpen(1004, 'DOOR_ALREADY_OPEN'),
  bleTimeout(1005, 'BLE_TIMEOUT'),
  unknownCommand(1006, 'UNKNOWN_COMMAND'),
  crcFailed(1007, 'CRC_FAILED'),
  expiredToken(1008, 'EXPIRED_TOKEN'),
  sequenceError(1009, 'SEQUENCE_ERROR'),
  doorJam(1101, 'DOOR_JAM'),
  boxEmpty(1102, 'BOX_EMPTY'),
  motorFailure(1103, 'MOTOR_FAILURE'),
  batteryLow(1104, 'BATTERY_LOW'),
  lowRssi(1105, 'LOW_RSSI'),
  disconnectDuringOpen(1106, 'DISCONNECT_DURING_OPEN');

  const McuErrorCode(this.code, this.wireName);
  final int code;
  final String wireName;
}

abstract final class McuLimits {
  static const protocolVersion = 1;
  static const orderId = 40;
  static const lockerId = 32;
  static const boxId = 32;
  static const collectionToken = 128;
  static const payload = 200;
  static const maxFrameBytes = 512;
}
