/// Campus Essentials Flutter BLE layer (Phase 11–13).
///
/// Architecture:
///   UI → [LockerService] → [BleProtocol] → [BleTransport]
///        → flutter_blue_plus (CC2340R5) | VirtualMCU | Mock
library;

export 'config/ble_config.dart';
export 'locker/locker_service.dart';
export 'managers/connection_manager.dart';
export 'managers/retry_manager.dart';
export 'managers/sequence_manager.dart';
export 'managers/timeout_manager.dart';
export 'models/ble_device.dart';
export 'models/locker_connection.dart';
export 'models/locker_state.dart';
export 'models/packet.dart';
export 'models/packet_header.dart';
export 'models/packet_payload.dart';
export 'models/packet_result.dart';
export 'protocol/ble_protocol.dart';
export 'protocol/checksum.dart';
export 'protocol/packet_codec.dart';
export 'protocol/packet_types.dart';
export 'providers/ble_providers.dart';
export 'transport/ble_link_state.dart';
export 'transport/ble_log.dart';
export 'transport/ble_transport.dart';
export 'transport/flutter_blue_transport.dart';
export 'transport/mock_ble_transport.dart';
export 'transport/virtual_mcu_transport.dart';
