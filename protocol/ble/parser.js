'use strict';

const { PROTOCOL_VERSION, LIMITS, PACKET_TYPE_NAMES } = require('./constants');
const { BlePacket } = require('./packetModel');
const {
  computeChecksumPlaceholder,
  verifyChecksumPlaceholder,
} = require('./checksum');

function readLengthPrefixedString(buffer, offset, maxLen) {
  if (offset >= buffer.length) {
    throw new Error('Unexpected end of frame while reading string length');
  }
  const len = buffer.readUInt8(offset);
  offset += 1;
  if (len > maxLen) {
    throw new Error(`String length ${len} exceeds max ${maxLen}`);
  }
  if (offset + len > buffer.length) {
    throw new Error('Unexpected end of frame while reading string');
  }
  const value = buffer.subarray(offset, offset + len).toString('utf8');
  return { value, offset: offset + len };
}

/**
 * Parses a binary frame into a BlePacket.
 * Verifies checksum placeholder; rejects CRC_FAILED conceptually via throw.
 *
 * @param {Buffer|string} frame Buffer or hex string
 * @returns {BlePacket}
 */
function parsePacket(frame) {
  let buffer = frame;
  if (typeof frame === 'string') {
    buffer = Buffer.from(frame.replace(/\s+/g, ''), 'hex');
  }
  if (!Buffer.isBuffer(buffer)) {
    throw new TypeError('Frame must be a Buffer or hex string');
  }
  if (buffer.length < 10) {
    throw new Error('Frame too short');
  }
  if (buffer.length > LIMITS.maxFrameBytes) {
    throw new Error('Frame too long');
  }

  if (!verifyChecksumPlaceholder(buffer)) {
    const err = new Error('CRC_FAILED: checksum placeholder mismatch');
    err.code = 'CRC_FAILED';
    throw err;
  }

  const body = buffer.subarray(0, buffer.length - 2);
  let offset = 0;

  const protocolVersion = body.readUInt8(offset);
  offset += 1;
  const packetTypeCode = body.readUInt8(offset);
  offset += 1;
  const sequenceNumber = body.readUInt16BE(offset);
  offset += 2;
  const timestamp = body.readUInt32BE(offset);
  offset += 4;

  if (protocolVersion !== PROTOCOL_VERSION) {
    throw new Error(`Unsupported protocolVersion: ${protocolVersion}`);
  }

  const order = readLengthPrefixedString(body, offset, LIMITS.orderId);
  offset = order.offset;
  const locker = readLengthPrefixedString(body, offset, LIMITS.lockerId);
  offset = locker.offset;
  const box = readLengthPrefixedString(body, offset, LIMITS.boxId);
  offset = box.offset;
  const token = readLengthPrefixedString(body, offset, LIMITS.collectionToken);
  offset = token.offset;

  if (offset + 2 > body.length) {
    throw new Error('Missing payloadLength');
  }
  const payloadLength = body.readUInt16BE(offset);
  offset += 2;
  if (payloadLength > LIMITS.payload) {
    throw new Error('payloadLength exceeds limit');
  }
  if (offset + payloadLength > body.length) {
    throw new Error('Truncated payload');
  }
  const payload = Buffer.from(body.subarray(offset, offset + payloadLength));
  offset += payloadLength;

  if (offset !== body.length) {
    throw new Error('Trailing bytes in frame body');
  }

  const checksum = buffer.readUInt16BE(buffer.length - 2);
  const packetTypeName = PACKET_TYPE_NAMES[packetTypeCode];
  if (!packetTypeName) {
    throw new Error(`UNKNOWN_COMMAND: packetType 0x${packetTypeCode.toString(16)}`);
  }

  const packet = new BlePacket({
    protocolVersion,
    packetType: packetTypeName,
    sequenceNumber,
    timestamp,
    orderId: order.value,
    lockerId: locker.value,
    boxId: box.value,
    collectionToken: token.value,
    payloadLength,
    payload,
    checksum,
  });

  // Recompute for callers that want expected value.
  packet.checksum = checksum;
  packet._checksumExpected = computeChecksumPlaceholder(body);

  return packet;
}

module.exports = {
  parsePacket,
};
