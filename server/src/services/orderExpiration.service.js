'use strict';

/**
 * Phase 23 — server-authoritative collection window expiration.
 *
 * Payment success starts a fixed collection window (default 2 hours).
 * Flutter countdown is visual only; this module is the authority.
 *
 * Clock is injectable for tests — never rely on client time.
 */

const AppError = require('../utils/AppError');

const PENDING_COLLECTION_STATUSES = Object.freeze([
  'READY_FOR_COLLECTION',
  'PAYMENT_SUCCESS',
]);

const UNPAID_STATUSES = Object.freeze(['CREATED', 'WAITING_PAYMENT']);

function getCollectionWindowMs() {
  const hours = Number(process.env.ORDER_COLLECTION_HOURS || 2);
  return Math.max(1, hours) * 60 * 60 * 1000;
}

function createClock(nowFn) {
  if (typeof nowFn === 'function') {
    return () => {
      const value = nowFn();
      return value instanceof Date ? value : new Date(value);
    };
  }
  return () => new Date();
}

function isPendingCollection(status) {
  return PENDING_COLLECTION_STATUSES.includes(status);
}

function computeCollectionDeadline(paidAt, { windowMs } = {}) {
  const paid = paidAt instanceof Date ? paidAt : new Date(paidAt);
  if (Number.isNaN(paid.getTime())) {
    throw new AppError('Invalid paidAt timestamp', 500);
  }
  const ms = windowMs != null ? windowMs : getCollectionWindowMs();
  return new Date(paid.getTime() + ms);
}

/**
 * Mutates + persists an order to EXPIRED when the collection deadline has passed.
 * Returns the (possibly updated) order document.
 *
 * @param {object} order — mongoose document or plain object with save-capable path
 * @param {object} [opts]
 * @param {() => Date} [opts.now]
 * @param {(id: any, data: object) => Promise<object>} [opts.persist] — preferred update fn
 */
async function ensureCollectionWindow(order, opts = {}) {
  if (!order || !isPendingCollection(order.status)) return order;
  if (order.paymentStatus !== 'SUCCESS') return order;
  if (order.collectionDeadline) return order;

  const paidAt =
    order.paidAt != null
      ? new Date(order.paidAt)
      : order.updatedAt != null
        ? new Date(order.updatedAt)
        : createClock(opts.now)();
  const collectionDeadline = computeCollectionDeadline(paidAt);
  const patch = { paidAt, collectionDeadline };

  if (typeof opts.persist === 'function') {
    const updated = await opts.persist(order._id || order.id, patch);
    return updated || Object.assign(order, patch);
  }
  Object.assign(order, patch);
  if (typeof order.save === 'function') {
    await order.save();
  }
  return order;
}

async function expireOrderIfNeeded(order, opts = {}) {
  if (!order) return order;
  const now = createClock(opts.now)();

  order = await ensureCollectionWindow(order, opts);

  if (!isPendingCollection(order.status)) {
    return order;
  }

  const deadline = order.collectionDeadline
    ? new Date(order.collectionDeadline)
    : null;

  if (!deadline || Number.isNaN(deadline.getTime())) {
    return order;
  }

  if (now.getTime() < deadline.getTime()) {
    return order;
  }

  const patch = {
    status: 'EXPIRED',
    expiredAt: now,
  };

  if (typeof opts.persist === 'function') {
    const updated = await opts.persist(order._id || order.id, patch);
    return updated || Object.assign(order, patch);
  }

  Object.assign(order, patch);
  if (typeof order.save === 'function') {
    await order.save();
  }
  return order;
}

/**
 * Throws AppError when the order cannot be collected right now.
 * Call after expireOrderIfNeeded so EXPIRED is already applied.
 */
function assertCollectible(order, opts = {}) {
  const now = createClock(opts.now)();

  if (!order) {
    throw new AppError('Order not found', 404);
  }

  if (order.status === 'COLLECTED') {
    throw new AppError('Order already collected', 400);
  }

  if (order.status === 'CANCELLED') {
    throw new AppError('Order cancelled', 400);
  }

  if (order.status === 'EXPIRED') {
    throw new AppError('Order expired', 400);
  }

  if (UNPAID_STATUSES.includes(order.status)) {
    throw new AppError('Payment not completed', 400);
  }

  if (!isPendingCollection(order.status)) {
    throw new AppError(
      `Collection not yet available (status=${order.status})`,
      400,
    );
  }

  if (order.paymentStatus !== 'SUCCESS') {
    throw new AppError('Payment not completed', 400);
  }

  if (!order.collectionDeadline) {
    throw new AppError('Collection deadline missing', 422);
  }

  const deadline = new Date(order.collectionDeadline);
  if (Number.isNaN(deadline.getTime())) {
    throw new AppError('Collection deadline missing', 422);
  }

  // Inclusive reject at/after deadline (race: Collect pressed as window ends).
  if (now.getTime() >= deadline.getTime()) {
    throw new AppError('Order expired', 400);
  }
}

module.exports = {
  PENDING_COLLECTION_STATUSES,
  UNPAID_STATUSES,
  getCollectionWindowMs,
  createClock,
  isPendingCollection,
  computeCollectionDeadline,
  ensureCollectionWindow,
  expireOrderIfNeeded,
  assertCollectible,
};
