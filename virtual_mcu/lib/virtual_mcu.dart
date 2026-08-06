/// Virtual CC2340 MCU simulator for Campus Essentials.
///
/// Independent of Flutter UI. Speak Phase 10 BLE wire frames.
/// Swap in via [VirtualMCUTransport] on the Flutter side.
library;

export 'src/authentication_engine.dart';
export 'src/box_runtime.dart';
export 'src/door_controller.dart';
export 'src/error_manager.dart';
export 'src/heartbeat_manager.dart';
export 'src/locker_matrix.dart';
export 'src/mcu_core.dart';
export 'src/motor_simulator.dart';
export 'src/packet_processor.dart';
export 'src/runtime_logger.dart';
export 'src/runtime_state.dart';
export 'src/sensor_simulator.dart';
export 'src/sequence_manager.dart';
export 'src/simulation_config.dart';
export 'src/wire/checksum.dart';
export 'src/wire/frame_codec.dart';
export 'src/wire/packet_types.dart';
