# Campus Essentials — BLE Protocol Specification

**Phase 10 — Protocol design only**

| Constraint | Status |
|------------|--------|
| No Flutter UI changes | Yes |
| No BLE radio / GATT implementation | Yes |
| No TI CC2340 firmware | Yes |
| No Payment API changes | Yes |
| No Order API changes | Yes |

## Architecture

```text
┌─────────┐     HTTPS      ┌──────────────┐
│  Phone  │ ◄────────────► │    Server    │
│ (App)   │                │ (no BLE)     │
└────┬────┘                └──────────────┘
     │
     │ BLE (GATT notify / write)
     ▼
┌─────────┐
│ TI CC2340│
│  Locker │
└─────────┘
```

- The **server is not connected to BLE**.
- The **phone is the secure bridge**: it obtains a short-lived `collectionToken` from the server (future phase) and presents it to the locker over BLE.
- This repository package (`protocol/ble`) defines framing, types, policies, and a reference serializer/parser. It does **not** open doors or talk to hardware.

## Goals

1. Define a versioned packet format usable by Flutter (later) and CC2340 firmware (later).
2. Cover collection happy-path: connect → auth → open box → complete.
3. Specify errors, retries, timeouts, and session state.
4. Design `collectionToken` format + expiry (crypto verification deferred).

## Packet fields (every frame)

| Field | Type | Description |
|-------|------|-------------|
| `protocolVersion` | `u8` | Currently `1` |
| `packetType` | `u8` | See [Packet types](#packet-types) |
| `sequenceNumber` | `u16` | Per-sender counter (0 reserved) |
| `timestamp` | `u32` | Unix time in seconds |
| `orderId` | string | Campus order number / id (may be empty on PING) |
| `lockerId` | string | Target locker business id |
| `boxId` | string | Target box business id |
| `collectionToken` | string | Short-lived token (required on AUTH / OPEN_BOX) |
| `payloadLength` | `u16` | Payload byte count |
| `payload` | bytes | Type-specific JSON (UTF-8) or empty |
| `checksum` | `u16` | **Placeholder** mix checksum (CRC later) |

## Binary frame layout

Big-endian:

```text
offset  size  field
------  ----  -----
0       1     protocolVersion
1       1     packetType
2       2     sequenceNumber
4       4     timestamp
8       1+N   orderId        (u8 length + UTF-8)
…       1+N   lockerId
…       1+N   boxId
…       1+N   collectionToken
…       2     payloadLength
…       M     payload
…       2     checksum
```

Limits: see `protocol/ble/constants.js` (`LIMITS`). Soft max frame: **512 bytes**.

## Packet types

| Name | Code | Direction | Expected reply |
|------|------|-----------|----------------|
| `PING` | `0x01` | Phone → Locker | `PONG` |
| `PONG` | `0x02` | Locker → Phone | — |
| `AUTH` | `0x10` | Phone → Locker | `AUTH_ACK` |
| `AUTH_ACK` | `0x11` | Locker → Phone | — |
| `OPEN_BOX` | `0x20` | Phone → Locker | `OPEN_ACK` |
| `OPEN_ACK` | `0x21` | Locker → Phone | — |
| `STATUS` | `0x30` | Phone → Locker | `STATUS_RESPONSE` |
| `STATUS_RESPONSE` | `0x31` | Locker → Phone | — |
| `ERROR` | `0x40` | Either | — |
| `HEARTBEAT` | `0x50` | Either | optional |
| `DISCONNECT` | `0x60` | Either | — |

## Error codes

Carried in `ERROR` payload JSON `{ code, name, message, retryable }`.

| Name | Code | Retryable |
|------|------|-----------|
| `INVALID_TOKEN` | 1001 | No |
| `INVALID_BOX` | 1002 | No |
| `LOCKER_BUSY` | 1003 | Yes |
| `DOOR_ALREADY_OPEN` | 1004 | No |
| `BLE_TIMEOUT` | 1005 | Yes (phone-side) |
| `UNKNOWN_COMMAND` | 1006 | No |
| `CRC_FAILED` | 1007 | Conditional |

## Session state machine

```text
IDLE → CONNECTED → AUTHENTICATED → OPEN_REQUEST → OPENING
  → OPEN_SUCCESS → COMPLETE
```

Failures transition to `FAILED`. See [STATE_MACHINE.md](./STATE_MACHINE.md).

## Security (design)

1. After payment success (existing Order `READY_FOR_COLLECTION`), **future** server API issues `collectionToken`.
2. Phone includes token in `AUTH` (and again on `OPEN_BOX`).
3. Locker validates **format + expiry + id binding** in Phase 10 design; **HMAC/signature** comes later.
4. Token format: `CE1.<orderId>.<lockerId>.<boxId>.<expiresAtUnix>.<nonce>`

See [SECURITY.md](./SECURITY.md).

## Reference package

| Path | Role |
|------|------|
| `protocol/ble/` | Models, serialize/parse, policies, state machine |
| `docs/ble-protocol/` | This documentation set |

```bash
node protocol/ble/selfcheck.js
```

## Related docs

- [PACKET_EXAMPLES.md](./PACKET_EXAMPLES.md)
- [SEQUENCE_DIAGRAMS.md](./SEQUENCE_DIAGRAMS.md)
- [STATE_MACHINE.md](./STATE_MACHINE.md)
- [DEVELOPER.md](./DEVELOPER.md)
- [SECURITY.md](./SECURITY.md)
