# Developer documentation — BLE protocol package

## Location

```text
protocol/ble/                 Reference implementation (Node, design-only)
docs/ble-protocol/            Human specification
```

## Module map

| File | Responsibility |
|------|----------------|
| `constants.js` | Version, packet types, error codes, limits, states |
| `packetModel.js` | `BlePacket`, payload JSON helpers |
| `checksum.js` | Checksum **placeholder** (+ future CRC name) |
| `serializer.js` | Object → binary frame |
| `parser.js` | Binary frame → object (rejects bad checksum) |
| `sequenceManager.js` | Outbound seq + inbound duplicate window |
| `retryPolicy.js` | Attempts, backoff, retryable errors |
| `timeoutPolicy.js` | Per-command timeouts, heartbeat, session idle |
| `stateMachine.js` | Session states / transitions |
| `collectionToken.js` | Token format + expiry validation |
| `index.js` | Public exports |
| `selfcheck.js` | Round-trip + state smoke |

## Quick start

```bash
# From repo root
node protocol/ble/selfcheck.js
```

```js
const ble = require('./protocol/ble');

const token = ble.buildCollectionToken({
  orderId: 'ORD-1',
  lockerId: 'LCK-A1',
  boxId: 'BOX-03',
});

const seq = new ble.SequenceNumberManager();
const packet = ble.createPacket('OPEN_BOX', {
  sequenceNumber: seq.next(),
  orderId: 'ORD-1',
  lockerId: 'LCK-A1',
  boxId: 'BOX-03',
  collectionToken: token,
  payload: ble.PayloadSchemas.openBox(),
});

const frame = ble.serializePacket(packet);
const again = ble.parsePacket(frame);
```

## Policies (defaults)

### RetryPolicy

- `maxAttempts`: 3  
- `baseDelayMs`: 400 (exponential, capped at 3000)  
- Retryable types: `PING`, `AUTH`, `OPEN_BOX`, `STATUS`, `HEARTBEAT`  
- Retryable errors: `LOCKER_BUSY` (1003), `BLE_TIMEOUT` (1005)

### TimeoutPolicy

| Operation | Default ms |
|-----------|------------|
| Connect | 8000 |
| PING | 1500 |
| AUTH | 3000 |
| OPEN_BOX | 5000 |
| STATUS | 2000 |
| Heartbeat interval | 5000 |
| Heartbeat miss limit | 3 |
| Session idle | 90000 |

## What not to do in Phase 10

- Do not add Flutter BLE plugins or UI
- Do not flash / write CC2340 firmware here
- Do not change Payment or Order routes to emit tokens yet
- Do not treat placeholder checksum as production CRC

## Porting notes (later phases)

| Consumer | Suggested use |
|----------|----------------|
| Flutter | Port frame layout + state machine; use platform BLE APIs |
| CC2340 | Implement parser/serializer in C; enforce token format |
| Server | Issue signed `CE1` tokens after `READY_FOR_COLLECTION` |

Keep `protocolVersion = 1` until a breaking change requires `2`.
