import 'dart:async';
import 'dart:typed_data';

import 'authentication_engine.dart';
import 'door_controller.dart';
import 'error_manager.dart';
import 'heartbeat_manager.dart';
import 'locker_matrix.dart';
import 'motor_simulator.dart';
import 'packet_processor.dart';
import 'runtime_logger.dart';
import 'runtime_state.dart';
import 'sensor_simulator.dart';
import 'sequence_manager.dart';
import 'simulation_config.dart';
import 'wire/frame_codec.dart';
import 'wire/packet_types.dart';

/// Top-level Virtual MCU — software stand-in for future CC2340 firmware.
class MCUCore {
  MCUCore({SimulationConfig? config})
      : config = config ?? const SimulationConfig() {
    matrix = LockerMatrix(this.config);
    state = McuRuntimeState(
      mcuId: this.config.mcuId,
      firmwareVersion: this.config.firmwareVersion,
      lockerId: this.config.lockerId,
      batteryLevel: this.config.initialBatteryPercent,
      temperature: this.config.initialTemperatureC,
      rssi: this.config.initialRssi,
    );
    logger = RuntimeLogger();
    sequences = SequenceManager();
    auth = AuthenticationEngine();
    doors = DoorController(this.config);
    motors = MotorSimulator(this.config);
    sensors = SensorSimulator();
    errors = ErrorManager(this.config);
    processor = PacketProcessor(
      config: this.config,
      matrix: matrix,
      state: state,
      logger: logger,
      sequences: sequences,
      auth: auth,
      doors: doors,
      motors: motors,
      sensors: sensors,
      errors: errors,
    );
    heartbeat = HeartbeatManager(
      config: this.config,
      onTick: (counter) {
        applyHeartbeatTick(state, counter);
        if (state.bleConnected) {
          final frame = const FrameCodec().encode(
            type: McuPacketType.heartbeat,
            sequenceNumber: sequences.nextOutbound(),
            lockerId: matrix.lockerId,
            payload: const FrameCodec().jsonPayload({
              'rssi': state.rssi,
              'counter': counter,
            }),
          );
          _outbound.add(frame);
          logger.log(event: 'HEARTBEAT', result: 'tick-$counter');
        }
      },
    );
  }

  final SimulationConfig config;
  late final LockerMatrix matrix;
  late final McuRuntimeState state;
  late final RuntimeLogger logger;
  late final SequenceManager sequences;
  late final AuthenticationEngine auth;
  late final DoorController doors;
  late final MotorSimulator motors;
  late final SensorSimulator sensors;
  late final ErrorManager errors;
  late final PacketProcessor processor;
  late final HeartbeatManager heartbeat;

  final _outbound = StreamController<Uint8List>.broadcast(sync: true);

  /// Unsolicited notifications (heartbeat, etc.).
  Stream<Uint8List> get outboundNotifications => _outbound.stream;

  void connectBle() {
    state.bleConnected = true;
    logger.log(event: 'BLE_CONNECTED', result: 'ok');
    heartbeat.start();
  }

  void disconnectBle() {
    state.bleConnected = false;
    state.resetSession();
    heartbeat.stop();
    logger.log(event: 'BLE_DISCONNECTED', result: 'ok');
  }

  Future<Uint8List?> handleWrite(Uint8List bytes) => processor.process(bytes);

  // --- Simulation control API (dev tools / tests) ---

  void reserveBox(String boxId) => matrix.reserve(boxId);

  void releaseBox(String boxId) => matrix.release(boxId);

  Future<void> openConfiguredBox(String boxId) async {
    final box = matrix.find(boxId);
    if (box == null) throw StateError('unknown box');
    motors.start(box);
    await doors.open(box);
    motors.stop(box);
  }

  void simulateCollection(String boxId) => matrix.simulateCollection(boxId);

  void resetLocker() {
    matrix.reset();
    logger.log(event: 'LOCKER_RESET', result: 'ok');
  }

  void resetMcu() {
    heartbeat.stop();
    heartbeat.reset();
    sequences.reset();
    state.resetSession();
    state.bleConnected = false;
    state.packetCounter = 0;
    state.heartbeatCounter = 0;
    state.lastPacket = null;
    state.lastError = null;
    matrix.reset();
    logger.clear();
    logger.log(event: 'MCU_RESET', result: 'ok');
  }

  Map<String, Object?> debugSnapshot() => {
        'runtime': state.toJson(),
        'matrix': matrix.snapshot(),
        'log': logger.toTable(),
      };

  Future<void> dispose() async {
    heartbeat.stop();
    await _outbound.close();
  }
}
