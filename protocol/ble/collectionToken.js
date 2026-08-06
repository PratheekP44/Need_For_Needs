'use strict';

/**
 * Collection token design (Phase 10 — format + expiry only).
 *
 * Server will generate short-lived tokens after successful payment in a later phase.
 * Locker validates FORMAT and EXPIRY now (design); cryptographic signature
 * verification is deferred.
 *
 * Token format (ASCII, single line):
 *   CE1.<orderId>.<lockerId>.<boxId>.<expiresAtUnix>.<nonce>
 *
 * Example:
 *   CE1.ORD-20260803121225-1301.LCK-A1.BOX-03.1722690000.a1b2c3d4
 */

const TOKEN_PREFIX = 'CE1';
const DEFAULT_TTL_SECONDS = 15 * 60; // align with order reservation window

/**
 * Build a design-time token string (NOT a signed production token).
 */
function buildCollectionToken({
  orderId,
  lockerId,
  boxId,
  expiresAtUnix,
  nonce,
  ttlSeconds = DEFAULT_TTL_SECONDS,
} = {}) {
  if (!orderId || !lockerId || !boxId) {
    throw new Error('orderId, lockerId, and boxId are required');
  }
  const exp =
    expiresAtUnix ??
    Math.floor(Date.now() / 1000) + Math.max(60, ttlSeconds);
  const n = nonce || randomNonce();
  return [TOKEN_PREFIX, orderId, lockerId, boxId, String(exp), n].join('.');
}

function randomNonce() {
  return Math.random().toString(16).slice(2, 10);
}

/**
 * Parse token into parts. Throws on malformed structure.
 */
function parseCollectionToken(token) {
  const raw = String(token || '').trim();
  const parts = raw.split('.');
  if (parts.length !== 6) {
    const err = new Error('INVALID_TOKEN: expected 6 dot-separated parts');
    err.code = 'INVALID_TOKEN';
    throw err;
  }
  const [prefix, orderId, lockerId, boxId, expStr, nonce] = parts;
  if (prefix !== TOKEN_PREFIX) {
    const err = new Error('INVALID_TOKEN: unsupported prefix');
    err.code = 'INVALID_TOKEN';
    throw err;
  }
  const expiresAtUnix = Number(expStr);
  if (!Number.isFinite(expiresAtUnix) || expiresAtUnix <= 0) {
    const err = new Error('INVALID_TOKEN: bad expiry');
    err.code = 'INVALID_TOKEN';
    throw err;
  }
  return {
    prefix,
    orderId,
    lockerId,
    boxId,
    expiresAtUnix,
    nonce,
    raw,
  };
}

/**
 * Format + expiry validation only (no HMAC / public-key check).
 *
 * @param {string} token
 * @param {object} [expected]
 * @param {string} [expected.orderId]
 * @param {string} [expected.lockerId]
 * @param {string} [expected.boxId]
 * @param {number} [nowUnix]
 * @param {number} [clockSkewSeconds=30]
 */
function validateCollectionTokenFormat(
  token,
  expected = {},
  nowUnix = Math.floor(Date.now() / 1000),
  clockSkewSeconds = 30,
) {
  const parsed = parseCollectionToken(token);

  if (expected.orderId && parsed.orderId !== expected.orderId) {
    const err = new Error('INVALID_TOKEN: orderId mismatch');
    err.code = 'INVALID_TOKEN';
    throw err;
  }
  if (expected.lockerId && parsed.lockerId !== expected.lockerId) {
    const err = new Error('INVALID_TOKEN: lockerId mismatch');
    err.code = 'INVALID_TOKEN';
    throw err;
  }
  if (expected.boxId && parsed.boxId !== expected.boxId) {
    const err = new Error('INVALID_BOX: boxId mismatch');
    err.code = 'INVALID_BOX';
    throw err;
  }

  if (nowUnix > parsed.expiresAtUnix + clockSkewSeconds) {
    const err = new Error('INVALID_TOKEN: token expired');
    err.code = 'INVALID_TOKEN';
    err.expired = true;
    throw err;
  }

  return {
    ok: true,
    parsed,
    expiresInSeconds: parsed.expiresAtUnix - nowUnix,
    cryptoVerification: 'deferred',
  };
}

module.exports = {
  TOKEN_PREFIX,
  DEFAULT_TTL_SECONDS,
  buildCollectionToken,
  parseCollectionToken,
  validateCollectionTokenFormat,
};
