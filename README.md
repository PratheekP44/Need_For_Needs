# Need For Needs / Campus Essentials

Monorepo for the Campus Essentials smart locker platform.

## Layout

| Path | Role |
|------|------|
| `lib/` | Flutter app (UI / client) |
| `lib/core/ble/` | Phase 11 Flutter BLE stack |
| `lib/features/developer_dashboard/` | **Phase 11.75** Developer Dashboard |
| `virtual_mcu/` | Phase 11.5 Virtual CC2340 MCU simulator |
| `server/` | Node.js + Express API |
| `docs/ble-protocol/` | Phase 10 BLE protocol specification |
| `docs/flutter-ble/` | Phase 11 Flutter BLE architecture docs |
| `docs/virtual-mcu/` | Phase 11.5 Virtual MCU docs |
| `docs/developer-dashboard/` | Phase 11.75 Developer Dashboard docs |
| `protocol/ble/` | Phase 10 protocol reference (Node, no radio) |

## Current focus

**Phase 11.75 — Developer Dashboard**

Hidden Virtual MCU console (splash logo long-press ×5, or type `developer` in Settings).

```bash
flutter test test/ble
flutter analyze
```

Docs: [docs/developer-dashboard/README.md](docs/developer-dashboard/README.md)

## Server

```bash
cd server
cp .env.example .env
npm install
npm run dev
```

See [server/README.md](server/README.md) for Auth, Locker, Stock, Cart, Order, and Payment APIs.
