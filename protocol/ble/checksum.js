'use strict';

/**
 * Checksum placeholder for Phase 10.
 *
 * Real CRC-16/CCITT (or similar) will replace this in a later firmware phase.
 * Current algorithm: simple additive + XOR mix over all frame bytes excluding
 * the trailing 2-byte checksum field. Deterministic and easy to port.
 */

/**
 * @param {Buffer} bufferWithoutChecksum
 * @returns {number} uint16
 */
function computeChecksumPlaceholder(bufferWithoutChecksum) {
  if (!Buffer.isBuffer(bufferWithoutChecksum)) {
    throw new TypeError('checksum input must be a Buffer');
  }

  let sum = 0;
  let xor = 0;
  for (let i = 0; i < bufferWithoutChecksum.length; i += 1) {
    const b = bufferWithoutChecksum[i];
    sum = (sum + b) & 0xffff;
    xor ^= b;
  }

  // Mix so both empty and sparse frames produce non-trivial values.
  const mixed = ((sum << 3) ^ (xor << 8) ^ bufferWithoutChecksum.length) & 0xffff;
  return mixed === 0 ? 0xce10 : mixed;
}

/**
 * @param {Buffer} fullFrame including trailing checksum
 * @returns {boolean}
 */
function verifyChecksumPlaceholder(fullFrame) {
  if (!Buffer.isBuffer(fullFrame) || fullFrame.length < 2) return false;
  const body = fullFrame.subarray(0, fullFrame.length - 2);
  const expected = computeChecksumPlaceholder(body);
  const actual = fullFrame.readUInt16BE(fullFrame.length - 2);
  return expected === actual;
}

module.exports = {
  computeChecksumPlaceholder,
  verifyChecksumPlaceholder,
  /** Documented future replacement algorithm name. */
  FUTURE_ALGORITHM: 'CRC-16/CCITT-FALSE',
};
