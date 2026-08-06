# Security design — collectionToken

> Phase 10 designs the token **format**, **binding**, and **expiry**.  
> It does **not** modify Payment or Order APIs and does **not** implement signing.

## Threat model (summary)

| Threat | Mitigation (now / later) |
|--------|---------------------------|
| Replay after collection window | Expiry timestamp in token |
| Token used on wrong locker/box | Embed `lockerId` + `boxId`; compare on AUTH |
| Client claims “paid” without proof | Server-issued token (future); never trust phone alone |
| Token forged | **Later:** HMAC/JWT signature verified on locker or via challenge |
| Server ↔ locker MITM over BLE | N/A — server has no BLE; phone is bridge |

## Lifecycle (future server step)

```text
Payment verified
  → Order READY_FOR_COLLECTION
  → Server generates collectionToken (TTL, e.g. 15 minutes)
  → Phone stores token for BLE AUTH / OPEN_BOX
  → Token expires → phone must refresh (future API)
```

Phase 10 does **not** add that API (Payment/Orders frozen).

## Token format

```text
CE1.<orderId>.<lockerId>.<boxId>.<expiresAtUnix>.<nonce>
```

| Part | Example | Notes |
|------|---------|-------|
| Prefix | `CE1` | Campus Essentials token version 1 |
| orderId | `ORD-...` | Binds to paid order |
| lockerId | `LCK-A1` | Must match connected locker |
| boxId | `BOX-03` | Must match target box |
| expiresAtUnix | `1893456000` | Unix seconds |
| nonce | `deadbeef` | Opaque uniqueness |

Reference helpers: `protocol/ble/collectionToken.js`

- `buildCollectionToken(...)` — design/demo builder  
- `validateCollectionTokenFormat(...)` — structure + expiry + id binding  
- Cryptographic verification: **`deferred`**

## Locker validation (Phase 10 design)

On `AUTH` (and again on `OPEN_BOX`):

1. Parse `CE1` structure → else `INVALID_TOKEN`
2. Compare `lockerId` / `boxId` to device config → else `INVALID_TOKEN` / `INVALID_BOX`
3. If `now > expiresAtUnix (+ skew)` → `INVALID_TOKEN` (expired)
4. **Skip** signature check until crypto phase

## Phone rules

- Include token on `AUTH` and `OPEN_BOX`
- Do not open if `AUTH_ACK.accepted !== true`
- On expiry, abort session (`FAILED`) and prompt user to refresh token (future)
- Never treat UI “payment success” as locker authority

## Defaults

| Parameter | Default |
|-----------|---------|
| TTL | 900 seconds (15 min) |
| Clock skew allowance | 30 seconds |
| Prefix | `CE1` |
