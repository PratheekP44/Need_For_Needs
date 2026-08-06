'use strict';

const { PROTOCOL_VERSION, LIMITS, PACKET_TYPES } = require('./constants');
const { BlePacket } = require('./packetModel');
const { computeChecksumPlaceholder } = require('./checksum');

function writeLengthPrefixedString(buffers, value, maxLen) {
  const str = String(value ?? '');
  const raw = Buffer.from(str, 'utf8');
  if (raw.length > maxLen) {
    throw new Error(`Field exceeds max length ${maxLen}`);
  }
  if (raw.length > 255) {
    throw new Error('Length-prefixed string cannot exceed 255 bytes');
  }
  buffers.push(Buffer.from([raw.length]));
  if (raw.length > 0) buffers.push(raw);
}

/**
 * Serializes a BlePacket to a binary frame.
 *
 * Frame layout (big-endian):
 *   protocolVersion   u8
 *   packetType        u8
 *   sequenceNumber    u16
 *   timestamp         u32  (unix seconds)
 *   orderId           u8 len + bytes
 *   lockerId          u8 len + bytes
 *   boxId             u8 len + bytes
 *   collectionToken   u8 len + bytes
 *   payloadLength     u16
 *   payload           bytes
 *   checksum          u16  (placeholder)
 */
function serializePacket(packetInput) {
  const packet =
    packetInput instanceof BlePacket ? packetInput : new BlePacket(packetInput);

  const validation = packet.validate();
  if (!validation.ok) {
    throw new Error(`Invalid packet: ${validation.errors.join('; ')}`);
  }

  const typeCode = packet.packetTypeCode;
  if (typeCode == null) {
    throw new Error(`Unknown packetType: ${packet.packetType}`);
  }

  const payload = packet.payloadBuffer();
  const parts = [];

  const header = Buffer.alloc(8);
  header.writeUInt8(packet.protocolVersion, 0);
  header.writeUInt8(typeCode, 1);
  header.writeUInt16BE(packet.sequenceNumber & 0xffff, 2);
  header.writeUInt32BE(packet.timestamp >>> 0, 4);
  parts.push(header);

  writeLengthPrefixedString(parts, packet.orderId, LIMITS.orderId);
  writeLengthPrefixedString(parts, packet.lockerId, LIMITS.lockerId);
  writeLengthPrefixedString(parts, packet.boxId, LIMITS.boxId);
  writeLengthPrefixedString(parts, packet.collectionToken, LIMITS.collectionToken);

  const payloadHeader = Buffer.alloc(2);
  payloadHeader.writeUInt16BE(payload.length, 0);
  parts.push(payloadHeader);
  if (payload.length > 0) parts.push(payload);

  const body = Buffer.concat(parts);
  if (body.length + 2 > LIMITS.maxFrameBytes) {
    throw new Error(`Frame exceeds maxFrameBytes (${LIMITS.maxFrameBytes})`);
  }

  const checksum = computeChecksumPlaceholder(body);
  const checksumBuf = Buffer.alloc(2);
  checksumBuf.writeUInt16BE(checksum, 0);

  const frame = Buffer.concat([body, checksumBuf]);
  packet.checksum = checksum;
  packet.payloadLength = payload.length;
  return frame;
}

/**
 * Convenience: serialize and return hex string for docs / logs.
 */
function serializeToHex(packetInput) {
  return serializePacket(packetInput).toString('hex');
}

module.exports = {
  serializePacket,
  serializeToHex,
  PACKET_TYPES,
  PROTOCOL_VERSION,
};
