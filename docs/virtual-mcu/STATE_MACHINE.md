# MCU session state (firmware view)

```text
POWER_ON
  → IDLE (bleConnected=false)
  → BLE_CONNECTED
  → AUTHENTICATED (after AUTH_ACK)
  → OPENING (motor + door)
  → DOOR_OPEN / ERROR
  → DISCONNECTED → IDLE
```

```mermaid
stateDiagram-v2
  [*] --> Idle
  Idle --> Connected: BLE connect
  Connected --> Authenticated: AUTH_ACK
  Authenticated --> Opening: OPEN_BOX
  Opening --> DoorOpen: OPEN_ACK
  Opening --> Error: jam/busy/token
  DoorOpen --> Connected: optional close
  Connected --> Idle: DISCONNECT
  Authenticated --> Idle: DISCONNECT
  Error --> Connected: recoverable
  Error --> Idle: fatal / disconnect
```

Phone-side `LockerState` (Phase 11) remains the UI-facing machine; this diagram is the **MCU-internal** view.
