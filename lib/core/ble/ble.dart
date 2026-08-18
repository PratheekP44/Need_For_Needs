/// Campus Essentials Flutter BLE layer (Phase 11–14).
///
/// Architecture:
///   UI → [UnlockService] / [LockerService] → [BleProtocol] → [BleTransport]
///        → flutter_blue_plus (CC2340R5) | VirtualMCU | Mock
///
/// Phase 14 adds [PacketBuilder], [PacketParser], [BleConnectionManager],
/// [UnlockService] without replacing the existing stack.
library;

export 'config/ble_config.dart';
export 'locker/locker_service.dart';
export 'managers/ble_connection_manager.dart';
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
export 'models/unlock_payload.dart';
export 'protocol/ble_protocol.dart';
export 'protocol/ble_response_observation.dart';
export 'protocol/box_unlock_mask.dart';
export 'protocol/checksum.dart';
export 'protocol/packet_builder.dart';
export 'protocol/packet_codec.dart';
export 'protocol/packet_parser.dart';
export 'protocol/packet_types.dart';
export 'protocol/parsed_ble_response.dart';
export 'protocol/real_packet_builder.dart';
export 'protocol/final_unlock_port.dart';
export 'protocol/final_unlock_packet_builder.dart';
export 'protocol/final_unlock_response_parser.dart';
export 'providers/ble_providers.dart';
export 'transport/ble_link_state.dart';
export 'transport/ble_log.dart';
export 'transport/ble_pipeline_timer.dart';
export 'transport/ble_transport.dart';
export 'transport/ble_write_payload.dart';
export 'transport/collect_ble_profiler.dart';
export 'transport/flutter_blue_transport.dart';
export 'transport/mock_ble_transport.dart';
export 'transport/virtual_mcu_transport.dart';
export 'unlock/ble_unlock_engine.dart';
export 'unlock/unlock_jwt_decoder.dart';
export 'unlock/unlock_payload_service.dart';
export 'unlock/unlock_service.dart';
export 'unlock/unlock_token_ledger.dart';
