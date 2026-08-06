/// Per-box runtime state inside the Virtual Locker Matrix.
class BoxRuntime {
  BoxRuntime({
    required this.boxId,
    this.doorState = DoorState.closed,
    this.lockState = LockState.locked,
    this.itemId,
    this.itemName,
    this.quantity = 0,
    this.reserved = false,
    this.busy = false,
    this.sensorState = SensorState.idle,
    this.motorState = MotorState.stopped,
    this.lastOpened,
    this.lastPacket,
    this.lastError,
  });

  final String boxId;
  DoorState doorState;
  LockState lockState;
  String? itemId;
  String? itemName;
  int quantity;
  bool reserved;
  bool busy;
  SensorState sensorState;
  MotorState motorState;
  DateTime? lastOpened;
  String? lastPacket;
  String? lastError;

  bool get isEmpty => quantity <= 0 || itemId == null;

  Map<String, Object?> toJson() => {
        'boxId': boxId,
        'doorState': doorState.name,
        'lockState': lockState.name,
        'itemId': itemId,
        'itemName': itemName,
        'quantity': quantity,
        'reserved': reserved,
        'busy': busy,
        'sensorState': sensorState.name,
        'motorState': motorState.name,
        'lastOpened': lastOpened?.toIso8601String(),
        'lastPacket': lastPacket,
        'lastError': lastError,
      };

  BoxRuntime copy() => BoxRuntime(
        boxId: boxId,
        doorState: doorState,
        lockState: lockState,
        itemId: itemId,
        itemName: itemName,
        quantity: quantity,
        reserved: reserved,
        busy: busy,
        sensorState: sensorState,
        motorState: motorState,
        lastOpened: lastOpened,
        lastPacket: lastPacket,
        lastError: lastError,
      );
}

enum DoorState { open, closed, jammed, unknown }

enum LockState { locked, unlocked, fault }

enum SensorState { idle, doorOpenDetected, doorClosedDetected, fault }

enum MotorState { stopped, running, fault }
