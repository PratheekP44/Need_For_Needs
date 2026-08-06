# Locker matrix

Default layout: **4 × 4 = 16 boxes**.

| Field | Description |
|-------|-------------|
| `boxId` | `BOX-01` … `BOX-16` |
| `doorState` | open / closed / jammed / unknown |
| `lockState` | locked / unlocked / fault |
| `itemId` / `itemName` / `quantity` | Stocked demo items on BOX-01…08 |
| `reserved` / `busy` | Reservation + in-motion flags |
| `sensorState` / `motorState` | Sensor + motor sim |
| `lastOpened` / `lastPacket` / `lastError` | Debug |

Configure via `SimulationConfig(rows:, cols:, lockerId:)`.

APIs on `MCUCore` / `LockerMatrix`:

- `reserveBox` / `releaseBox`
- `openConfiguredBox`
- `simulateCollection`
- `resetLocker`
