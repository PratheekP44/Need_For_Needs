'use strict';

/**
 * Self-check for Phase 10 BLE protocol design package.
 * Run: node protocol/ble/selfcheck.js
 */

const assert = require('assert');
const path = require('path');
const ble = require('./index');

function main() {
  const seq = new ble.SequenceNumberManager();
  const s1 = seq.next();
  const s2 = seq.next();
  assert.strictEqual(s1, 1);
  assert.strictEqual(s2, 2);

  const token = ble.buildCollectionToken({
    orderId: 'ORD-DEMO-1',
    lockerId: 'LCK-A1',
    boxId: 'BOX-03',
    expiresAtUnix: Math.floor(Date.now() / 1000) + 600,
    nonce: 'deadbeef',
  });
  const tokenCheck = ble.validateCollectionTokenFormat(token, {
    orderId: 'ORD-DEMO-1',
    lockerId: 'LCK-A1',
    boxId: 'BOX-03',
  });
  assert.strictEqual(tokenCheck.ok, true);

  const auth = ble.createPacket('AUTH', {
    sequenceNumber: seq.next(),
    orderId: 'ORD-DEMO-1',
    lockerId: 'LCK-A1',
    boxId: 'BOX-03',
    collectionToken: token,
    payload: ble.PayloadSchemas.auth({
      tokenExpiresAt: Math.floor(Date.now() / 1000) + 600,
      phoneNonce: 'n1',
    }),
  });

  const frame = ble.serializePacket(auth);
  const parsed = ble.parsePacket(frame);
  assert.strictEqual(parsed.packetTypeName, 'AUTH');
  assert.strictEqual(parsed.orderId, 'ORD-DEMO-1');
  assert.strictEqual(parsed.collectionToken, token);

  // Tamper → CRC_FAILED
  const tampered = Buffer.from(frame);
  tampered[8] = tampered[8] ^ 0xff;
  let crcFailed = false;
  try {
    ble.parsePacket(tampered);
  } catch (error) {
    crcFailed = error.code === 'CRC_FAILED';
  }
  assert.strictEqual(crcFailed, true);

  const sm = new ble.BleSessionStateMachine();
  sm.handle('ble_connected');
  sm.handle('auth_ok');
  sm.handle('open_requested');
  sm.handle('open_sent');
  sm.handle('open_ack_ok');
  sm.handle('collection_done');
  assert.strictEqual(sm.getState(), 'COMPLETE');

  const retry = new ble.RetryPolicy();
  assert.strictEqual(retry.shouldRetry({ attempt: 1, packetType: 'OPEN_BOX' }), true);
  assert.strictEqual(retry.shouldRetry({ attempt: 3, packetType: 'OPEN_BOX' }), false);

  const timeouts = new ble.TimeoutPolicy();
  assert.ok(timeouts.responseTimeoutMs('AUTH') > 0);

  // Expired token
  const expired = ble.buildCollectionToken({
    orderId: 'ORD-DEMO-1',
    lockerId: 'LCK-A1',
    boxId: 'BOX-03',
    expiresAtUnix: Math.floor(Date.now() / 1000) - 120,
    nonce: 'old',
  });
  let expiredOk = false;
  try {
    ble.validateCollectionTokenFormat(expired);
  } catch (error) {
    expiredOk = error.code === 'INVALID_TOKEN' && error.expired === true;
  }
  assert.strictEqual(expiredOk, true);

  console.log('phase10_ble_protocol_selfcheck_ok');
  console.log(
    JSON.stringify(
      {
        protocolVersion: ble.PROTOCOL_VERSION,
        authHexPreview: frame.toString('hex').slice(0, 64) + '...',
        frameBytes: frame.length,
        packetTypes: Object.keys(ble.PACKET_TYPES),
        docs: path.resolve(__dirname, '../../docs/ble-protocol'),
      },
      null,
      2,
    ),
  );
}

main();
