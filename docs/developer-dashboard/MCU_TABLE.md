# MCU runtime table

Engineering diff log — not a second source of truth.

Whenever the dashboard refreshes from `MCUCore` (packet, outbound heartbeat, simulation action), it compares a flat map of variables:

- `authenticated`, `bleConnected`, `packetCounter`, `heartbeatCounter`
- `battery`, `rssi`, `lastPacket`, `lastError`
- per-box `door:BOX-xx`, `lock:BOX-xx`, `busy:BOX-xx`

On change, append:

| Timestamp | Variable | Previous | Current | Reason |

Reasons look like `open_box`, `packet_AUTH_ACK`, `low_battery`, `attach`.
