# Migration to CC2340 firmware (Phase 13)

## Goal

Use real TI CC2340R5 BLE **without** changing Flutter UI business APIs,
`LockerService`, or `BleProtocol`.

## Architecture (unchanged)

```text
UI
 ↓
LockerService
 ↓
BleProtocol
 ↓
BleTransport
 ↓
FlutterBluePlus  →  CC2340R5
   or
VirtualMCUTransport (dev)
```

## GATT profile (firmware-provided)

| Role | UUID |
|------|------|
| Service | `3f43d273-e6d2-d4bf-a948-08de3193ed76` |
| Char 1 Command (WRITE, 100 B) | `3f43d273-e6d2-d4bf-a948-08de3293ed76` |
| Char 4 Status (NOTIFY/READ, 16 B) | `3f43d273-e6d2-d4bf-a948-08de3393ed76` |

Configured once in `lib/core/ble/config/ble_config.dart`.

## Switch transport (no code change)

**In app**

1. Settings → **Developer · BLE transport** → Real BLE  
   or open **BLE Debug** and use the Virtual MCU / Real BLE segmented control.
2. Admin → **BLE Debug (CC2340)**.

**In code**

```dart
ref.read(bleConfigProvider.notifier).useRealBle();
// or
BleConfig.hardware()
```

Virtual MCU remains the default via `BleConfig.development()`.

## Packet flow

```text
App → BleProtocol.encode → Char 1 Write (with response when supported)
CC2340 → Char 4 Notify → BleProtocol.decode → LockerService
```

## What must stay stable

- Phase 10 wire frame + packet types
- `LockerService` public methods
- `BleTransport` interface

## What changes

| Before | After |
|--------|-------|
| Placeholder CE10/CE11/CE12 UUIDs | CC2340R5 UUIDs above |
| Virtual MCU only | Virtual MCU **or** FlutterBluePlus |
| No BLE Debug UI | `/ble-debug` bring-up screen |
