import '../protocol/packet_types.dart';

/// Per-command timeouts (Phase 10 defaults).
class TimeoutManager {
  const TimeoutManager({
    this.connect = const Duration(seconds: 8),
    this.ping = const Duration(milliseconds: 1500),
    this.auth = const Duration(seconds: 3),
    this.openBox = const Duration(seconds: 5),
    this.status = const Duration(seconds: 2),
    this.heartbeatInterval = const Duration(seconds: 5),
    this.heartbeatMissLimit = 3,
    this.sessionIdle = const Duration(seconds: 90),
    this.disconnectGrace = const Duration(seconds: 1),
  });

  final Duration connect;
  final Duration ping;
  final Duration auth;
  final Duration openBox;
  final Duration status;
  final Duration heartbeatInterval;
  final int heartbeatMissLimit;
  final Duration sessionIdle;
  final Duration disconnectGrace;

  Duration responseTimeout(BlePacketType type) {
    switch (type) {
      case BlePacketType.ping:
        return ping;
      case BlePacketType.auth:
        return auth;
      case BlePacketType.openBox:
        return openBox;
      case BlePacketType.status:
        return status;
      case BlePacketType.heartbeat:
        return ping;
      default:
        return ping;
    }
  }
}
