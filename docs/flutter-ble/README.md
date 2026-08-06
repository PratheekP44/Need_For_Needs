# Flutter BLE Architecture (Phase 11)

**Scope:** Flutter BLE client layer only.

| Frozen | Status |
|--------|--------|
| Backend / Auth / Payments / Orders / DB models | Untouched |
| Phase 10 BLE protocol specification | Untouched (ported, not modified) |
| TI CC2340 firmware | Not implemented |
| Flutter UI redesign | Not done |

## Layering

```text
Flutter UI
    ↓
LockerService          Business layer (auth token, open box, status, state)
    ↓
BleProtocol            Packet encode/decode, seq, retry, timeout
    ↓
BleTransport           Scan / connect / GATT R/W / notify
    ↓
flutter_blue_plus  or  MockBleTransport
    ↓
BLE Device (hardware) / simulated locker
```

**Do not** create a monolithic `BleService`.  
**Do not** build packets in UI widgets.

## Directory map

```text
lib/core/ble/
  config/ble_config.dart          Configurable UUIDs + timeouts
  models/                         BleDevice, Packet*, LockerState, …
  managers/                       Sequence, Retry, Timeout, Connection
  transport/                      Abstract + FlutterBlue + Mock
  protocol/                       Codec, checksum, BleProtocol, types
  locker/locker_service.dart      UI-facing API
  providers/ble_providers.dart    Riverpod
  ble.dart                        Barrel export
```

## Interaction flow

1. UI watches Riverpod providers (`connectionStateProvider`, …).
2. UI calls `ref.read(lockerServiceProvider).collectFromLocker(...)` (or step APIs).
3. `LockerService` updates `LockerState`, validates `collectionToken` format/expiry.
4. `BleProtocol` builds `Packet`, encodes with Phase 10 framing, writes via `ConnectionManager`.
5. `BleTransport` delivers bytes; notifications return; protocol decodes + matches sequence.
6. Business interprets `AUTH_ACK` / `OPEN_ACK` / `ERROR` and exposes clean results.

## Mock mode

`BleConfig.development()` sets `useMockTransport: true`.

`MockBleTransport` simulates connection, AUTH, OPEN, STATUS, ERROR, and optional timeouts — no hardware.

Switch to hardware:

```dart
bleConfigProvider.overrideWithValue(BleConfig.hardware());
```

## Riverpod providers

| Provider | Emits |
|----------|--------|
| `bleConfigProvider` | `BleConfig` |
| `lockerServiceProvider` | `LockerService` |
| `bluetoothStateProvider` | adapter state |
| `connectionStateProvider` | `LockerState` |
| `nearbyLockersProvider` | `List<BleDevice>` |
| `currentLockerProvider` | `LockerConnection` |
| `lockerStatusProvider` | status map |
| `doorStatusProvider` | door string |
| `packetStreamProvider` | decoded `Packet` |

## State machine

`Disconnected → Scanning → Connecting → Connected → Authenticating → Authenticated → Opening → WaitingResponse → Success | Failure → Disconnected`

## Public API reference

See [API.md](./API.md) for every public class.

## Tests

```bash
flutter test test/ble
flutter analyze
```

## Permissions

Android / iOS BLE usage strings and permissions were added for real transport.  
`android:required="false"` on BLE feature keeps the app installable without a radio (mock development).
