import 'simulation_config.dart';
import 'wire/packet_types.dart';

/// Maps simulation flags and runtime conditions to [McuErrorCode].
class ErrorManager {
  ErrorManager(this.config);

  final SimulationConfig config;

  McuErrorCode? preflightBle() {
    if (config.forceBleTimeout) return McuErrorCode.bleTimeout;
    if (config.forceBatteryLow) return McuErrorCode.batteryLow;
    if (config.forceLowRssi) return McuErrorCode.lowRssi;
    return null;
  }

  McuErrorCode fromException(Object error) {
    final text = error.toString();
    if (text.contains('DOOR_JAM')) return McuErrorCode.doorJam;
    if (text.contains('MOTOR_FAILURE')) return McuErrorCode.motorFailure;
    if (text.contains('CRC_FAILED')) return McuErrorCode.crcFailed;
    return McuErrorCode.unknownCommand;
  }
}
