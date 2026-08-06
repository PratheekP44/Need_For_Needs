# Packet flow

```text
BleProtocol.encode(Packet)
    → BleTransport.write(bytes)
        → VirtualMCUTransport
            → MCUCore.handleWrite
                → PacketProcessor (decode, validate, act)
            ← response bytes (or null = drop / timeout / disconnect)
        → notificationStream
    → BleProtocol.decode → PacketResult
```

Supported: `PING/PONG`, `AUTH/AUTH_ACK`, `OPEN_BOX/OPEN_ACK`, `STATUS/STATUS_RESPONSE`, `HEARTBEAT`, `ERROR`, `DISCONNECT`.

Validation:

- checksum placeholder (Phase 10 algorithm)
- sequence duplicates
- `CE1` collection token format + expiry
- box existence, door already open, busy, empty, motor/door faults
