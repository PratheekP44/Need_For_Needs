# Java BleHandler vs Flutter BLE — Phase 13 comparison

Reference: production Android `BleHandler.java` (SmartAAP SAAP SDK).  
Flutter stack: `UI → LockerService → BleProtocol → BleTransport → flutter_blue_plus`.

**Important:** SmartAAP uses a different GATT profile (C1/C3/C4) and an
encrypted frame protocol. Campus Essentials keeps Phase 10 frames + CC2340
UUIDs. This document compares *link-layer / production robustness* patterns.

## Comparison table

| Java feature | Flutter equivalent | Status |
|--------------|-------------------|--------|
| Connect with timeout | `FlutterBlueTransport.connect` + `BleConfig.connectTimeout` | **Implemented** |
| Disconnect + GATT close | `disconnect()` clears chars, queues, flags | **Implemented** |
| Auto reconnect | `ConnectionManager` auto-reconnect + rediscover/notify | **Implemented** |
| GATT error 133 retry | Connect loop retries on 133 / `gatt_error` | **Implemented** |
| HandlerThread serialization | Write queue + FBP per-device mutex | **Implemented** |
| Status flags (CONNECTED, MTU_SET, …) | `BleLinkState` / `BleLinkFlags` | **Implemented** |
| Request MTU 512 | `desiredMtu: 512`, accept negotiated lower | **Implemented** |
| Connection priority HIGH | Android `requestConnectionPriority(high)` | **Implemented** |
| Discover services + validate chars | Discover + require service/Char1/Char4 | **Implemented** |
| CCCD 0x2902 notify enable | `setNotifyValue(true)` + CCCD presence check | **Implemented** |
| Wait for write complete before next | Serialized `_writeQueue` + write timeout | **Implemented** |
| Inter-write sleep(100) | `BleConfig.writeSpacing` | **Implemented** |
| Notification → processReport | Notify → `BleProtocol.decode` → streams | **Implemented** (Phase 10 decode) |
| RSSI polling | Periodic `readRssi` + `rssiStream` | **Implemented** |
| BT disabled check | `BT_NOT_ENABLED` / adapter state | **Implemented** |
| Bad service / missing char errors | Explicit `BT No Services` / `BT Bad Service` | **Implemented** |
| Structured TX/RX/connect logs | `BleLog` | **Implemented** |
| Packet retry (app layer) | `RetryManager` in `BleProtocol` | **Implemented** |
| C1 token write + C3 encrypted command | Phase 10 single command characteristic | **N/A (different protocol)** |
| Handshake + UTC + frame counter + AES | SmartAAP `frameMessage` / `Utils.encryptMsg` | **Missing (by design)** — document only |
| Frame key persistence (`SdkInfo`) | Not applicable to Phase 10 token model | **Missing (by design)** |
| Report → NOTIF_LOCK_* events | Phase 10 `AUTH_ACK` / `OPEN_ACK` / status maps | **Partial** (different event model) |
| JWT server report upload | Backend payment/order APIs | **N/A** (app architecture) |
| MDM flight-mode toggle on 133 | Not portable / not desired in consumer app | **Missing (intentionally skipped)** |
| Config root/PBK/tag tokens | Campus Essentials collection token (CE1…) | **N/A (different product)** |

## Encryption / handshake (explicit)

Java builds a 16-byte plaintext frame (action, handshake, UTC, SDK bytes,
counter, index), derives a frame key, and AES-encrypts before writing C3.

Flutter Phase 10 sends validated binary packets via `PacketCodec` on the
CC2340 command characteristic. **Do not port SmartAAP crypto into Flutter**
unless firmware adopts that framing. Required for SmartAAP compatibility
(future, firmware-coordinated only):

1. Frame key derivation (`Utils.createKey`)
2. AES message encrypt/decrypt
3. Handshake nonce + counter replay protection
4. Dual-characteristic token (C1) + command (C3) sequencing

## Architecture confirmation

Unchanged:

```text
UI → LockerService → BleProtocol → BleTransport → flutter_blue_plus
```

Virtual MCU remains the default development transport.
