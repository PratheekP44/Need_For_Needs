import 'package:virtual_mcu/virtual_mcu.dart';

/// Snapshot of MCU status for the developer dashboard.
class McuStatusView {
  const McuStatusView({
    required this.mcuId,
    required this.firmwareVersion,
    required this.virtualMcuVersion,
    required this.bleConnected,
    required this.authenticated,
    required this.currentUser,
    required this.currentOrder,
    required this.lockerId,
    required this.batteryPercent,
    required this.temperatureC,
    required this.rssi,
    required this.heartbeatCounter,
    required this.packetCounter,
    required this.uptimeSeconds,
    required this.lastPacket,
    required this.lastAck,
    required this.lastError,
  });

  factory McuStatusView.fromMcu(MCUCore mcu, {String? lastAck}) {
    final s = mcu.state;
    return McuStatusView(
      mcuId: s.mcuId,
      firmwareVersion: s.firmwareVersion,
      virtualMcuVersion: '11.5.0',
      bleConnected: s.bleConnected,
      authenticated: s.authenticated,
      currentUser: s.currentUser,
      currentOrder: s.currentOrder,
      lockerId: s.currentLocker ?? s.lockerId,
      batteryPercent: s.batteryLevel,
      temperatureC: s.temperature,
      rssi: s.rssi,
      heartbeatCounter: s.heartbeatCounter,
      packetCounter: s.packetCounter,
      uptimeSeconds: s.uptimeSeconds,
      lastPacket: s.lastPacket,
      lastAck: lastAck,
      lastError: s.lastError,
    );
  }

  final String mcuId;
  final String firmwareVersion;
  final String virtualMcuVersion;
  final bool bleConnected;
  final bool authenticated;
  final String? currentUser;
  final String? currentOrder;
  final String lockerId;
  final int batteryPercent;
  final double temperatureC;
  final int rssi;
  final int heartbeatCounter;
  final int packetCounter;
  final int uptimeSeconds;
  final String? lastPacket;
  final String? lastAck;
  final String? lastError;
}

/// Live packet monitor row.
class PacketMonitorEntry {
  const PacketMonitorEntry({
    required this.timestamp,
    required this.direction,
    required this.sequenceNumber,
    required this.packetType,
    required this.payload,
    required this.ack,
    required this.result,
  });

  final DateTime timestamp;
  final PacketDirection direction;
  final int sequenceNumber;
  final String packetType;
  final String payload;
  final String ack;
  final String result;
}

enum PacketDirection { appToMcu, mcuToApp }

/// Engineering variable-change row.
class McuTableRow {
  const McuTableRow({
    required this.timestamp,
    required this.variable,
    required this.previousValue,
    required this.currentValue,
    required this.reason,
  });

  final DateTime timestamp;
  final String variable;
  final String previousValue;
  final String currentValue;
  final String reason;
}

/// Aggregated dashboard statistics.
class DashboardStats {
  const DashboardStats({
    this.packetsSent = 0,
    this.packetsReceived = 0,
    this.ackCount = 0,
    this.errorCount = 0,
    this.doorOpens = 0,
    this.doorCloses = 0,
    this.authCount = 0,
    this.reconnectCount = 0,
    this.totalResponseMs = 0,
    this.responseSamples = 0,
  });

  final int packetsSent;
  final int packetsReceived;
  final int ackCount;
  final int errorCount;
  final int doorOpens;
  final int doorCloses;
  final int authCount;
  final int reconnectCount;
  final int totalResponseMs;
  final int responseSamples;

  double get averageResponseMs =>
      responseSamples == 0 ? 0 : totalResponseMs / responseSamples;

  double get successPercent {
    final total = packetsSent;
    if (total == 0) return 100;
    final ok = packetsReceived; // simplistic
    return (ok / total * 100).clamp(0, 100);
  }

  DashboardStats copyWith({
    int? packetsSent,
    int? packetsReceived,
    int? ackCount,
    int? errorCount,
    int? doorOpens,
    int? doorCloses,
    int? authCount,
    int? reconnectCount,
    int? totalResponseMs,
    int? responseSamples,
  }) {
    return DashboardStats(
      packetsSent: packetsSent ?? this.packetsSent,
      packetsReceived: packetsReceived ?? this.packetsReceived,
      ackCount: ackCount ?? this.ackCount,
      errorCount: errorCount ?? this.errorCount,
      doorOpens: doorOpens ?? this.doorOpens,
      doorCloses: doorCloses ?? this.doorCloses,
      authCount: authCount ?? this.authCount,
      reconnectCount: reconnectCount ?? this.reconnectCount,
      totalResponseMs: totalResponseMs ?? this.totalResponseMs,
      responseSamples: responseSamples ?? this.responseSamples,
    );
  }
}

enum ArchitectureNode {
  flutterApp,
  lockerService,
  bleProtocol,
  virtualMcuTransport,
  mcuCore,
  lockerMatrix,
}
