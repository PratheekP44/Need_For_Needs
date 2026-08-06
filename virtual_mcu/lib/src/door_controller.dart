import 'box_runtime.dart';
import 'simulation_config.dart';

/// Simulates door open/close timing and door sensor feedback.
class DoorController {
  DoorController(this.config);

  final SimulationConfig config;

  Future<void> open(BoxRuntime box) async {
    box.motorState = MotorState.running;
    box.sensorState = SensorState.idle;
    await Future<void>.delayed(config.openDelay);
    if (config.forceDoorJam) {
      box.doorState = DoorState.jammed;
      box.motorState = MotorState.fault;
      box.sensorState = SensorState.fault;
      box.lockState = LockState.fault;
      throw StateError('DOOR_JAM');
    }
    box.lockState = LockState.unlocked;
    box.doorState = DoorState.open;
    box.motorState = MotorState.stopped;
    box.sensorState = SensorState.doorOpenDetected;
    box.lastOpened = DateTime.now();
  }

  Future<void> close(BoxRuntime box) async {
    box.motorState = MotorState.running;
    await Future<void>.delayed(config.closeDelay);
    box.doorState = DoorState.closed;
    box.lockState = LockState.locked;
    box.motorState = MotorState.stopped;
    box.sensorState = SensorState.doorClosedDetected;
  }
}
