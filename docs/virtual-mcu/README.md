# Virtual MCU Simulator (Phase 11.5)

Software stand-in for future **TI CC2340** locker firmware.

| Constraint | Status |
|------------|--------|
| Flutter UI unchanged | Yes |
| Backend / Auth / Payments / Orders unchanged | Yes |
| Phase 10 protocol spec unchanged | Yes |
| Phase 11 BLE architecture unchanged | Yes (transport swap only) |
| No real firmware | Yes |

## Architecture

```text
Flutter UI
    ↓
LockerService
    ↓
BleProtocol          (unchanged)
    ↓
BleTransport
    ↓
VirtualMCUTransport  ← development default
    ↓
virtual_mcu (MCUCore)
    ↓
Virtual Locker Matrix (4×4)
```

Later:

```text
BleTransport → FlutterBlueTransport → real CC2340 firmware
```

Only the transport binding changes.

## Module layout

```text
virtual_mcu/                 Independent Dart package
  lib/src/
    mcu_core.dart
    packet_processor.dart
    authentication_engine.dart
    locker_matrix.dart
    box_runtime.dart
    door_controller.dart
    sensor_simulator.dart
    motor_simulator.dart
    heartbeat_manager.dart
    error_manager.dart
    sequence_manager.dart
    runtime_logger.dart
    runtime_state.dart
    simulation_config.dart
    wire/                    Phase 10–compatible framing
```

Flutter adapter: `lib/core/ble/transport/virtual_mcu_transport.dart`

## Docs in this folder

- [STATE_MACHINE.md](./STATE_MACHINE.md)
- [LOCKER_MATRIX.md](./LOCKER_MATRIX.md)
- [RUNTIME.md](./RUNTIME.md)
- [PACKET_FLOW.md](./PACKET_FLOW.md)
- [MIGRATION_CC2340.md](./MIGRATION_CC2340.md)

## Run tests

```bash
# Package unit + stress tests
cd virtual_mcu && dart test

# Flutter integration (LockerService ↔ Virtual MCU)
cd .. && flutter test test/ble
flutter analyze
```
