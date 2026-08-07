'use strict';

const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const orderRepository = require('../repositories/order.repository');
const AppError = require('../utils/AppError');
const { loadEnv } = require('../config/env');
const { issueCollectionToken } = require('./admin.service');
const { createTokenId } = require('../utils/token');
const logger = require('../config/logger');

/**
 * Parses a positive int from locker / box labels (`LCK-01`, `BOX-03`, `3`).
 */
function parsePositiveInt(value, { max = 255 } = {}) {
  if (value == null) return null;
  if (typeof value === 'number' && Number.isFinite(value)) {
    const n = Math.trunc(value);
    return n > 0 && n <= max ? n : null;
  }
  const text = String(value).trim();
  if (!text) return null;
  const asInt = Number.parseInt(text, 10);
  if (Number.isFinite(asInt) && asInt > 0 && asInt <= max) return asInt;
  const match = text.match(/(\d+)/);
  if (!match) return null;
  const n = Number.parseInt(match[1], 10);
  return Number.isFinite(n) && n > 0 && n <= max ? n : null;
}

function resolveLockerDoc(order) {
  return order.locker && typeof order.locker === 'object' ? order.locker : null;
}

function resolveFirstLine(order) {
  return Array.isArray(order.items) && order.items.length ? order.items[0] : null;
}

function resolveBoxDoc(order) {
  const line = resolveFirstLine(order);
  return line?.box && typeof line.box === 'object' ? line.box : null;
}

function resolveBleDevice(locker) {
  if (!locker?.BLEDevice) return null;
  return typeof locker.BLEDevice === 'object' ? locker.BLEDevice : null;
}

function maskMac(value) {
  const text = String(value || '');
  if (text.length < 8) return '***';
  return `${text.slice(0, 2)}:**:**:**:${text.slice(-5)}`;
}

function resolveUnlockTtlSeconds(config) {
  const raw = Number(config.unlockJwtTtlSeconds);
  if (!Number.isFinite(raw) || raw <= 0) {
    return 10 * 60;
  }
  return Math.trunc(raw);
}

/**
 * Production Unlock JWT issuer (Phase 15B).
 *
 * HTTP returns only `{ jwt }`. Claims are the single source of truth.
 * Replay hooks are in-memory stubs until Redis/DB persistence lands.
 */
class UnlockPayloadService {
  constructor() {
    /** @type {Map<string, { orderId: string, status: 'issued' | 'used' | 'invalidated', expiresAt: number }>} */
    this._jtiLedger = new Map();
  }

  async issue(auth, orderId) {
    const order = await orderRepository.findByIdOrOrderNumberForUnlock(orderId);
    if (!order) {
      throw new AppError('Order not found', 404);
    }
    if (auth.role !== 'admin' && String(order.user) !== String(auth.sub)) {
      throw new AppError('Forbidden', 403);
    }

    if (!['READY_FOR_COLLECTION', 'PAYMENT_SUCCESS'].includes(order.status)) {
      throw new AppError(
        `Order is not ready for unlock (status=${order.status})`,
        400,
      );
    }

    const locker = resolveLockerDoc(order);
    const box = resolveBoxDoc(order);
    const line = resolveFirstLine(order);
    const ble = resolveBleDevice(locker);

    const lockerId = locker?.lockerId || line?.locker?.lockerId || '';
    const boxIdRaw = box?.boxId || box?.boxNumber;
    const boxId =
      boxIdRaw != null && String(boxIdRaw).trim()
        ? String(boxIdRaw).trim()
        : '';
    const boxNumber =
      parsePositiveInt(box?.boxNumber) ||
      parsePositiveInt(box?.boxId) ||
      parsePositiveInt(boxId);
    const port = boxNumber;
    // DB is source of truth — never derive terminal from lockerId.
    const terminalId = parsePositiveInt(locker?.terminalNumber);

    if (!lockerId) {
      throw new AppError('Order locker id is missing', 422);
    }
    if (!boxId || boxNumber == null || port == null) {
      throw new AppError('Order box / port information is missing', 422);
    }
    if (terminalId == null) {
      throw new AppError(
        'Locker terminalNumber is not configured — assign it on the Locker record',
        422,
      );
    }
    if (!ble?.macAddress) {
      throw new AppError(
        'Locker BLE device / bluetoothAddress is not configured',
        422,
      );
    }

    const bluetoothAddress = String(ble.macAddress).trim();
    const advertisementId = String(
      ble.advertisementId || ble.deviceName || '',
    ).trim();
    if (!advertisementId) {
      throw new AppError(
        'Locker BLE advertisementId / deviceName is not configured',
        422,
      );
    }

    const config = loadEnv();
    if (!config.unlockJwtSecret) {
      throw new AppError('UNLOCK_JWT_SECRET is not configured', 500);
    }

    const ttlSeconds = resolveUnlockTtlSeconds(config);
    const issuedAt = new Date();
    const expiry = new Date(issuedAt.getTime() + ttlSeconds * 1000);
    const expiryUnix = Math.floor(expiry.getTime() / 1000);

    let unlockToken = order.collectionToken || '';
    const existingExpiry = order.collectionTokenExpiresAt
      ? new Date(order.collectionTokenExpiresAt)
      : null;
    const tokenStale =
      !unlockToken ||
      !existingExpiry ||
      existingExpiry.getTime() <= Date.now() + 30 * 1000;

    if (tokenStale) {
      unlockToken = issueCollectionToken({
        orderNumber: order.orderNumber,
        lockerId,
        boxId,
        ttlSeconds,
      });
      await orderRepository.updateById(order._id, {
        collectionToken: unlockToken,
        collectionTokenExpiresAt: expiry,
      });
    }

    const transactionId = String(
      order.transaction?._id ||
        order.transaction ||
        order.gatewayPaymentId ||
        '',
    );
    if (!transactionId) {
      throw new AppError('Order transactionId is missing', 422);
    }

    const rawItemId =
      (line?.item &&
        typeof line.item === 'object' &&
        (line.item.itemId || line.item._id)) ||
      line?.item ||
      null;
    const itemId = rawItemId != null ? String(rawItemId) : null;

    const jti = createTokenId() || crypto.randomUUID();

    const claims = {
      typ: 'unlock',
      jti,
      orderId: String(order._id),
      transactionId,
      unlockToken,
      bluetoothAddress,
      advertisementId,
      terminalId,
      port,
      boxNumber,
      lockerId: String(lockerId),
      boxId: String(boxId),
      itemId,
      issuedAt: issuedAt.toISOString(),
      expiry: expiry.toISOString(),
    };

    let unlockJwt;
    try {
      unlockJwt = jwt.sign(claims, config.unlockJwtSecret, {
        algorithm: 'HS256',
        expiresIn: ttlSeconds,
        jwtid: jti,
      });
    } catch (error) {
      logger.error('Unlock JWT sign failed', { message: error.message });
      throw new AppError('Failed to sign unlock JWT', 500);
    }

    this._recordIssuedJti(jti, {
      orderId: String(order._id),
      expiresAt: expiryUnix,
    });

    logger.info('Unlock JWT issued', {
      jti,
      orderId: String(order._id),
      terminalId,
      port,
      boxNumber,
      lockerId,
      bluetoothAddress: maskMac(bluetoothAddress),
      advertisementId,
      ttlSeconds,
    });
    logger.info('Unlock JWT expires', {
      jti,
      expiry: expiry.toISOString(),
      issuedAt: issuedAt.toISOString(),
    });

    return { jwt: unlockJwt };
  }

  /**
   * Verify signature + claims. Used by future confirm / locker redeem paths.
   */
  verifyUnlockJwt(unlockJwt) {
    const config = loadEnv();
    if (!config.unlockJwtSecret) {
      throw new AppError('UNLOCK_JWT_SECRET is not configured', 500);
    }

    let claims;
    try {
      claims = jwt.verify(unlockJwt, config.unlockJwtSecret, {
        algorithms: ['HS256'],
      });
    } catch (error) {
      logger.warn('Unlock JWT rejected', {
        reason: error.name || 'verify_failed',
        message: error.message,
      });
      if (error.name === 'TokenExpiredError') {
        throw new AppError('Unlock JWT expired', 401);
      }
      if (error.name === 'JsonWebTokenError') {
        throw new AppError('Unlock JWT signature invalid or malformed', 401);
      }
      throw new AppError(`Invalid unlock JWT: ${error.message}`, 401);
    }

    if (claims.typ !== 'unlock') {
      logger.warn('Unlock JWT rejected', { reason: 'wrong_typ', jti: claims.jti });
      throw new AppError('JWT is not an unlock token', 401);
    }

    const required = [
      'jti',
      'orderId',
      'transactionId',
      'unlockToken',
      'bluetoothAddress',
      'advertisementId',
      'terminalId',
      'port',
      'boxNumber',
      'lockerId',
      'boxId',
      'issuedAt',
      'expiry',
    ];
    for (const key of required) {
      if (claims[key] === undefined || claims[key] === null || claims[key] === '') {
        logger.warn('Unlock JWT rejected', { reason: 'missing_claim', claim: key });
        throw new AppError(`Unlock JWT missing required claim: ${key}`, 401);
      }
    }

    logger.info('Unlock JWT decoded', {
      jti: claims.jti,
      orderId: claims.orderId,
      expiry: claims.expiry,
    });

    return claims;
  }

  /** Future replay-protection: mark jti as used after successful unlock. */
  async markUnlockTokenUsed(jti) {
    const key = String(jti || '');
    if (!key) return;
    const existing = this._jtiLedger.get(key) || {
      orderId: '',
      expiresAt: Math.floor(Date.now() / 1000) + 600,
    };
    this._jtiLedger.set(key, { ...existing, status: 'used' });
    logger.info('Unlock token marked used', { jti: key });
  }

  /** Future replay-protection: force-invalidate a jti. */
  async invalidateUnlockToken(jti) {
    const key = String(jti || '');
    if (!key) return;
    const existing = this._jtiLedger.get(key) || {
      orderId: '',
      expiresAt: Math.floor(Date.now() / 1000) + 600,
    };
    this._jtiLedger.set(key, { ...existing, status: 'invalidated' });
    logger.info('Unlock token invalidated', { jti: key });
  }

  /** Future replay-protection: whether jti was already used/invalidated. */
  async isUnlockTokenUsed(jti) {
    const entry = this._jtiLedger.get(String(jti || ''));
    if (!entry) return false;
    return entry.status === 'used' || entry.status === 'invalidated';
  }

  /**
   * Verify + consume once. Not wired to Collect yet.
   */
  async verifyAndConsume(unlockJwt, { markConsumed = true } = {}) {
    const claims = this.verifyUnlockJwt(unlockJwt);
    const jti = String(claims.jti);

    if (await this.isUnlockTokenUsed(jti)) {
      logger.warn('Unlock JWT rejected', { reason: 'already_used', jti });
      throw new AppError('Unlock JWT already used', 409);
    }

    if (markConsumed) {
      await this.markUnlockTokenUsed(jti);
    }
    return claims;
  }

  _recordIssuedJti(jti, { orderId, expiresAt }) {
    this._jtiLedger.set(String(jti), {
      orderId: String(orderId),
      status: 'issued',
      expiresAt: Number(expiresAt),
    });
    this._pruneExpiredJtis();
  }

  _pruneExpiredJtis() {
    const now = Math.floor(Date.now() / 1000);
    for (const [jti, entry] of this._jtiLedger.entries()) {
      if (entry.expiresAt < now) this._jtiLedger.delete(jti);
    }
  }
}

module.exports = new UnlockPayloadService();
