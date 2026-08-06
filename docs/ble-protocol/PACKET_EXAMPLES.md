# Packet examples

Examples use the reference serializer in `protocol/ble`. Hex dumps are illustrative; run `selfcheck.js` for live values.

## Common context

```text
orderId           = ORD-DEMO-1
lockerId          = LCK-A1
boxId             = BOX-03
collectionToken   = CE1.ORD-DEMO-1.LCK-A1.BOX-03.1893456000.deadbeef
protocolVersion   = 1
```

## 1. PING (phone → locker)

**JSON view**

```json
{
  "protocolVersion": 1,
  "packetType": "PING",
  "sequenceNumber": 1,
  "timestamp": 1722691200,
  "orderId": "",
  "lockerId": "LCK-A1",
  "boxId": "",
  "collectionToken": "",
  "payloadLength": 0,
  "payload": "",
  "checksum": "<u16>"
}
```

## 2. PONG (locker → phone)

```json
{
  "protocolVersion": 1,
  "packetType": "PONG",
  "sequenceNumber": 1,
  "timestamp": 1722691201,
  "orderId": "",
  "lockerId": "LCK-A1",
  "boxId": "",
  "collectionToken": "",
  "payloadLength": 0,
  "payload": "",
  "checksum": "<u16>"
}
```

## 3. AUTH (phone → locker)

Token carried in header field `collectionToken`. Payload adds optional metadata.

```json
{
  "protocolVersion": 1,
  "packetType": "AUTH",
  "sequenceNumber": 2,
  "timestamp": 1722691202,
  "orderId": "ORD-DEMO-1",
  "lockerId": "LCK-A1",
  "boxId": "BOX-03",
  "collectionToken": "CE1.ORD-DEMO-1.LCK-A1.BOX-03.1893456000.deadbeef",
  "payloadLength": 73,
  "payload": {
    "tokenIssuedAt": 1722690000,
    "tokenExpiresAt": 1893456000,
    "phoneNonce": "n1"
  },
  "checksum": "<u16>"
}
```

## 4. AUTH_ACK (locker → phone)

```json
{
  "protocolVersion": 1,
  "packetType": "AUTH_ACK",
  "sequenceNumber": 2,
  "timestamp": 1722691203,
  "orderId": "ORD-DEMO-1",
  "lockerId": "LCK-A1",
  "boxId": "BOX-03",
  "collectionToken": "",
  "payload": {
    "accepted": true,
    "sessionTtlSeconds": 120,
    "firmwareVersion": "0.0.0-design"
  }
}
```

## 5. OPEN_BOX (phone → locker)

```json
{
  "protocolVersion": 1,
  "packetType": "OPEN_BOX",
  "sequenceNumber": 3,
  "timestamp": 1722691205,
  "orderId": "ORD-DEMO-1",
  "lockerId": "LCK-A1",
  "boxId": "BOX-03",
  "collectionToken": "CE1.ORD-DEMO-1.LCK-A1.BOX-03.1893456000.deadbeef",
  "payload": { "reason": "collection" }
}
```

## 6. OPEN_ACK (locker → phone)

```json
{
  "protocolVersion": 1,
  "packetType": "OPEN_ACK",
  "sequenceNumber": 3,
  "timestamp": 1722691206,
  "orderId": "ORD-DEMO-1",
  "lockerId": "LCK-A1",
  "boxId": "BOX-03",
  "collectionToken": "",
  "payload": {
    "opened": true,
    "doorState": "OPEN",
    "boxStatus": "AVAILABLE"
  }
}
```

## 7. STATUS / STATUS_RESPONSE

**STATUS request**

```json
{
  "packetType": "STATUS",
  "lockerId": "LCK-A1",
  "boxId": "BOX-03",
  "payload": { "includeDoor": true }
}
```

**STATUS_RESPONSE**

```json
{
  "packetType": "STATUS_RESPONSE",
  "payload": {
    "doorState": "CLOSED",
    "boxStatus": "AVAILABLE",
    "batteryMv": 3300,
    "uptimeSeconds": 86400
  }
}
```

## 8. ERROR

```json
{
  "packetType": "ERROR",
  "orderId": "ORD-DEMO-1",
  "lockerId": "LCK-A1",
  "boxId": "BOX-03",
  "payload": {
    "code": 1001,
    "name": "INVALID_TOKEN",
    "message": "token expired",
    "retryable": false
  }
}
```

## 9. HEARTBEAT

```json
{
  "packetType": "HEARTBEAT",
  "lockerId": "LCK-A1",
  "payload": { "rssi": -62 }
}
```

## 10. DISCONNECT

```json
{
  "packetType": "DISCONNECT",
  "lockerId": "LCK-A1",
  "payloadLength": 0,
  "payload": ""
}
```

## Generating a live hex sample

```bash
node -e "const ble=require('./protocol/ble'); const t=ble.buildCollectionToken({orderId:'ORD-DEMO-1',lockerId:'LCK-A1',boxId:'BOX-03',nonce:'deadbeef',expiresAtUnix:1893456000}); const p=ble.createPacket('AUTH',{sequenceNumber:2,timestamp:1722691202,orderId:'ORD-DEMO-1',lockerId:'LCK-A1',boxId:'BOX-03',collectionToken:t,payload:ble.PayloadSchemas.auth({tokenExpiresAt:1893456000,phoneNonce:'n1'})}); console.log(ble.serializeToHex(p)); console.log(JSON.stringify(ble.parsePacket(ble.serializePacket(p)).toJSON(),null,2));"
```
