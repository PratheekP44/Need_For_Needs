import 'box_runtime.dart';

/// Door / occupancy sensor readings.
class SensorSimulator {
  SensorState readDoor(BoxRuntime box) {
    switch (box.doorState) {
      case DoorState.open:
        return SensorState.doorOpenDetected;
      case DoorState.closed:
        return SensorState.doorClosedDetected;
      case DoorState.jammed:
      case DoorState.unknown:
        return SensorState.fault;
    }
  }

  bool isDoorOpen(BoxRuntime box) => box.doorState == DoorState.open;
}
