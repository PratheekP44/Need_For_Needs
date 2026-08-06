# Developer Dashboard (Phase 11.75)

Debugging / demo console over the **existing Virtual MCU**.

It does **not** change production architecture, backend, customer shopping UI (beyond hidden entry), BLE protocol, or Virtual MCU internals.

## Access (hidden)

1. **Splash logo** — long-press the logo **5 times** within ~2.2s  
2. **Settings** — type `developer` in the search field  

Route: `/developer-dashboard` (not linked in normal navigation).

## Architecture

```text
Developer Dashboard (visualization)
        ↓ reads / triggers
LockerService → BleProtocol → VirtualMCUTransport → MCUCore → Locker Matrix
```

Business logic stays in Virtual MCU + LockerService. Widgets only render Riverpod state.

## Docs

- [FEATURES.md](./FEATURES.md)
- [SCREENS.md](./SCREENS.md)
- [DEMO_GUIDE.md](./DEMO_GUIDE.md)
- [MCU_TABLE.md](./MCU_TABLE.md)
