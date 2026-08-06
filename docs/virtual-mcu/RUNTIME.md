# Runtime variables

`McuRuntimeState` mirrors the debug table we expect on CC2340:

| Variable | Meaning |
|----------|---------|
| `mcuId` | Simulator / device id |
| `firmwareVersion` | e.g. `0.1.0-virtual` |
| `bleConnected` | Link up |
| `authenticated` | AUTH succeeded |
| `currentUser` / `currentOrder` / `currentLocker` / `currentBox` | Session |
| `batteryLevel` / `temperature` / `rssi` | Telemetry |
| `heartbeatCounter` / `packetCounter` / `uptime` | Counters |
| `lastPacket` / `lastError` | Last RX / fault |

## Runtime log table

`RuntimeLogger` entries:

`timestamp · event · packet · box · door · lock · result`

Access: `mcu.logger.toTable()` or `mcu.debugSnapshot()`.
