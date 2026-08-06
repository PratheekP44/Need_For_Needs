# Public API — Flutter BLE layer

All symbols are exported from `package:need_for_needs/core/ble/ble.dart`.

## Configuration

### `BleConfig`
Central GATT + transport settings. **Only place** UUID strings are defined.

| Member | Role |
|--------|------|
| `serviceUuid` / `writeCharacteristicUuid` / `notifyCharacteristicUuid` | Configurable `Guid`s |
| `deviceNamePrefix` | Scan filter (`CE-LOCKER`) |
| `useMockTransport` | Prefer `MockBleTransport` |
| `development()` / `hardware()` | Factories |
| `copyWith` | Immutable overrides |

---

## Models

### `BleDevice`
Discovered peripheral: `id`, `name`, `rssi`, `advertisementName`, `isConnectable`.

### `LockerConnection`
Session snapshot: device, `LockerState`, locker/box/order ids, MTU, `authenticated`, `lastError`.

### `LockerState`
Enum: `disconnected`, `scanning`, `connecting`, `connected`, `authenticating`, `authenticated`, `opening`, `waitingResponse`, `success`, `failure`.

### `PacketHeader`
Protocol header fields (`protocolVersion`, `packetType`, `sequenceNumber`, `timestamp`, ids, token, `payloadLength`).

### `PacketPayload`
Payload bytes + factories: `auth`, `authAck`, `openBox`, `openAck`, `statusRequest`, `statusResponse`, `error`, `heartbeat`.

### `Packet`
Header + payload + checksum; `build`, `validate`, `toJson`.

### `PacketResult`
`success`, request/response packets, `errorCode`, `message`, `timedOut`.

---

## Protocol

### `BlePacketType` / `BleErrorCode` / `BleProtocolLimits`
Phase 10 wire codes and limits (ported, not changed upstream).

### `computeChecksumPlaceholder` / `verifyChecksumPlaceholder`
Phase 10 placeholder checksum.

### `PacketCodec`
`encode(Packet)` / `decode(Uint8List)`.

### `BleProtocol`
Packet layer over `ConnectionManager`.

| Method | Description |
|--------|-------------|
| `attachNotifications` | Bind notify stream |
| `encode` / `decode` | Framing |
| `ping` / `authenticate` / `openBox` / `requestStatus` / `heartbeat` | Typed exchanges |
| `sendDisconnect` | Best-effort DISCONNECT |
| `exchange` | Generic retry/timeout loop |
| `packetStream` | Decoded packets |

---

## Transport

### `BleTransport` (abstract)
Scan, connect, disconnect, MTU, discover, R/W, notifications, permissions, adapter state, streams. **No parsing.**

### `FlutterBlueTransport`
`flutter_blue_plus` + `permission_handler` implementation.

### `MockBleTransport`
Simulated locker for development/tests. Flags: `failAuth`, `failOpen`, `simulateTimeouts`.

### `BleAdapterState`
Normalized adapter enum for providers.

---

## Managers

### `SequenceManager`
Outbound uint16 sequences; inbound duplicate window.

### `RetryManager`
`shouldRetry`, `delayForAttempt` (exponential + jitter).

### `TimeoutManager`
Per-command timeouts (Phase 10 defaults).

### `ConnectionManager`
Connect / disconnect / auto-reconnect / write / notify bridge over transport.

---

## Business

### `LockerService`
UI-facing façade.

| Method | Description |
|--------|-------------|
| `scanForLockers` | Discovery |
| `connect` | Link + discover + notify |
| `authenticateCollection` | Token format/expiry + AUTH |
| `openBox` | OPEN_BOX after auth |
| `requestLockerStatus` / `getDoorStatus` | STATUS |
| `disconnectSafely` | DISCONNECT + drop link |
| `collectFromLocker` | End-to-end convenience |
| streams | state, connection, nearby, status, door, packets |

---

## Riverpod

See `ble_providers.dart`: `bleConfigProvider`, `lockerServiceProvider`, `bluetoothStateProvider`, `connectionStateProvider`, `nearbyLockersProvider`, `currentLockerProvider`, `lockerStatusProvider`, `doorStatusProvider`, `packetStreamProvider`.
