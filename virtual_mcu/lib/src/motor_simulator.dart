import 'box_runtime.dart';
import 'simulation_config.dart';

/// Latch motor simulation.
class MotorSimulator {
  MotorSimulator(this.config);

  final SimulationConfig config;

  void start(BoxRuntime box) {
    if (config.forceMotorFailure) {
      box.motorState = MotorState.fault;
      throw StateError('MOTOR_FAILURE');
    }
    box.motorState = MotorState.running;
  }

  void stop(BoxRuntime box) {
    if (box.motorState != MotorState.fault) {
      box.motorState = MotorState.stopped;
    }
  }
}
