/// Simulation knobs for the Virtual MCU (faults, delays, matrix size).
class SimulationConfig {
  const SimulationConfig({
    this.rows = 4,
    this.cols = 4,
    this.lockerId = 'LCK-A1',
    this.mcuId = 'VMCU-CE-001',
    this.firmwareVersion = '0.1.0-virtual',
    this.openDelay = const Duration(milliseconds: 120),
    this.closeDelay = const Duration(milliseconds: 80),
    this.doorTimeout = const Duration(seconds: 30),
    this.heartbeatInterval = const Duration(seconds: 5),
    this.packetLossRate = 0.0,
    this.forceInvalidToken = false,
    this.forceExpiredToken = false,
    this.forceDoorJam = false,
    this.forceMotorFailure = false,
    this.forceBusy = false,
    this.forceCrcFailureOnResponse = false,
    this.forceSequenceError = false,
    this.forceBatteryLow = false,
    this.forceLowRssi = false,
    this.forceDisconnectDuringOpen = false,
    this.forceBleTimeout = false,
    this.initialBatteryPercent = 92,
    this.initialTemperatureC = 28.5,
    this.initialRssi = -55,
  });

  final int rows;
  final int cols;
  final String lockerId;
  final String mcuId;
  final String firmwareVersion;
  final Duration openDelay;
  final Duration closeDelay;
  final Duration doorTimeout;
  final Duration heartbeatInterval;

  /// 0.0–1.0 probability of dropping an inbound packet (no response).
  final double packetLossRate;

  final bool forceInvalidToken;
  final bool forceExpiredToken;
  final bool forceDoorJam;
  final bool forceMotorFailure;
  final bool forceBusy;
  final bool forceCrcFailureOnResponse;
  final bool forceSequenceError;
  final bool forceBatteryLow;
  final bool forceLowRssi;
  final bool forceDisconnectDuringOpen;
  final bool forceBleTimeout;

  final int initialBatteryPercent;
  final double initialTemperatureC;
  final int initialRssi;

  int get boxCount => rows * cols;

  SimulationConfig copyWith({
    int? rows,
    int? cols,
    String? lockerId,
    Duration? openDelay,
    double? packetLossRate,
    bool? forceInvalidToken,
    bool? forceExpiredToken,
    bool? forceDoorJam,
    bool? forceMotorFailure,
    bool? forceBusy,
    bool? forceCrcFailureOnResponse,
    bool? forceSequenceError,
    bool? forceBatteryLow,
    bool? forceLowRssi,
    bool? forceDisconnectDuringOpen,
    bool? forceBleTimeout,
  }) {
    return SimulationConfig(
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
      lockerId: lockerId ?? this.lockerId,
      mcuId: mcuId,
      firmwareVersion: firmwareVersion,
      openDelay: openDelay ?? this.openDelay,
      closeDelay: closeDelay,
      doorTimeout: doorTimeout,
      heartbeatInterval: heartbeatInterval,
      packetLossRate: packetLossRate ?? this.packetLossRate,
      forceInvalidToken: forceInvalidToken ?? this.forceInvalidToken,
      forceExpiredToken: forceExpiredToken ?? this.forceExpiredToken,
      forceDoorJam: forceDoorJam ?? this.forceDoorJam,
      forceMotorFailure: forceMotorFailure ?? this.forceMotorFailure,
      forceBusy: forceBusy ?? this.forceBusy,
      forceCrcFailureOnResponse:
          forceCrcFailureOnResponse ?? this.forceCrcFailureOnResponse,
      forceSequenceError: forceSequenceError ?? this.forceSequenceError,
      forceBatteryLow: forceBatteryLow ?? this.forceBatteryLow,
      forceLowRssi: forceLowRssi ?? this.forceLowRssi,
      forceDisconnectDuringOpen:
          forceDisconnectDuringOpen ?? this.forceDisconnectDuringOpen,
      forceBleTimeout: forceBleTimeout ?? this.forceBleTimeout,
      initialBatteryPercent: initialBatteryPercent,
      initialTemperatureC: initialTemperatureC,
      initialRssi: initialRssi,
    );
  }
}
