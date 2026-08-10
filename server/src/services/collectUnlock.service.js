'use strict';

const orderRepository = require('../repositories/order.repository');
const AppError = require('../utils/AppError');
const { formatOrder } = require('./order.service');
const logger = require('../config/logger');
const {
  expireOrderIfNeeded,
  assertCollectible,
} = require('./orderExpiration.service');

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

/**
 * Collect all physical box numbers from order lines (Phase 20 multi-box).
 * Deduplicates; validates firmware range 1–32.
 */
function resolveBoxNumbers(order) {
  const lines = Array.isArray(order.items) ? order.items : [];
  const seen = new Set();
  const boxes = [];
  for (const line of lines) {
    const boxDoc = line?.box && typeof line.box === 'object' ? line.box : null;
    const n =
      parsePositiveInt(boxDoc?.boxNumber, { max: 32 }) ||
      parsePositiveInt(boxDoc?.boxId, { max: 32 });
    if (n == null) continue;
    if (seen.has(n)) continue;
    seen.add(n);
    boxes.push(n);
  }
  return boxes;
}

function resolveFirstLine(order) {
  return Array.isArray(order.items) && order.items.length ? order.items[0] : null;
}

function assertOwner(auth, order) {
  if (
    auth.role !== 'admin' &&
    String(order.user?._id || order.user) !== String(auth.sub)
  ) {
    throw new AppError('Forbidden', 403);
  }
}

function assertNotDeleted(order) {
  if (order?.deletedAt) {
    throw new AppError('Order not found', 404);
  }
}

/**
 * Expire if needed, then enforce collect eligibility (server clock).
 */
async function prepareCollectableOrder(auth, orderId, opts = {}) {
  let order = await orderRepository.findByIdOrOrderNumberForUnlock(orderId);
  if (!order) {
    // Fallback without BLE populate for markCollected path.
    order = await orderRepository.findByIdOrOrderNumber(orderId);
  }
  if (!order) {
    throw new AppError('Order not found', 404);
  }
  assertNotDeleted(order);
  assertOwner(auth, order);

  order = await expireOrderIfNeeded(order, {
    now: opts.now,
    persist: (oid, data) => orderRepository.updateById(oid, data),
  });

  assertCollectible(order, { now: opts.now });
  return order;
}

/**
 * Phase 20 — dynamic unlock info for Collect (no Unlock JWT).
 *
 * Returns order-sourced port, terminalNumber, and boxNumbers[] for the
 * firmware 4-byte unlock bitmap. Never hardcodes Port/Box/Terminal = 1.
 *
 * Phase 23 — collectionDeadline enforced before any unlock data is returned.
 */
class CollectUnlockService {
  async getUnlockInfo(auth, orderId, opts = {}) {
    const order = await prepareCollectableOrder(auth, orderId, opts);

    const locker = resolveLockerDoc(order);
    const line = resolveFirstLine(order);
    const boxNumbers = resolveBoxNumbers(order);

    const resolvedOrderId = String(order._id);
    const lockerId = locker?.lockerId || line?.locker?.lockerId || '';
    const terminalNumber = parsePositiveInt(locker?.terminalNumber);

    const item = line?.item && typeof line.item === 'object' ? line.item : null;
    const itemId =
      (item?.itemId != null && String(item.itemId).trim()) ||
      (item?._id != null ? String(item._id) : '') ||
      '';

    if (!lockerId) {
      throw new AppError('Order locker id is missing', 422);
    }
    if (!boxNumbers.length) {
      throw new AppError('Order box / port information is missing', 422);
    }
    if (terminalNumber == null) {
      throw new AppError(
        'Locker terminalNumber is not configured — assign it on the Locker record',
        422,
      );
    }

    const transactionId = String(
      order.transaction || order.gatewayPaymentId || order.orderNumber || '',
    ).trim();

    // Port from first/primary box when app model treats Port ≈ Box.
    // Never hardcode 1 — DB is source of truth.
    const port = boxNumbers[0];
    const boxNumber = boxNumbers[0];

    logger.info(
      {
        orderId: resolvedOrderId,
        lockerId,
        terminalNumber,
        boxNumber,
        boxNumbers,
        port,
        itemId,
        transactionId,
        collectionDeadline: order.collectionDeadline,
      },
      'unlock-info issued (Phase 20 multi-box bitmap, no JWT)',
    );

    return {
      orderId: resolvedOrderId,
      orderNumber: order.orderNumber || '',
      lockerId,
      terminalNumber,
      boxNumber,
      boxNumbers,
      port,
      itemId,
      transactionId,
      paidAt: order.paidAt || null,
      collectionDeadline: order.collectionDeadline || null,
      status: order.status,
    };
  }

  /**
   * Mark order COLLECTED after successful BLE unlock on device.
   * Re-validates deadline so an expired order cannot be marked collected.
   */
  async markCollected(auth, orderId, opts = {}) {
    let order = await orderRepository.findByIdOrOrderNumber(orderId);
    if (!order) {
      throw new AppError('Order not found', 404);
    }
    assertNotDeleted(order);
    assertOwner(auth, order);

    if (order.status === 'COLLECTED') {
      return formatOrder(order);
    }

    order = await expireOrderIfNeeded(order, {
      now: opts.now,
      persist: (oid, data) => orderRepository.updateById(oid, data),
    });
    assertCollectible(order, { now: opts.now });

    const updated = await orderRepository.updateById(order._id, {
      status: 'COLLECTED',
      collectedAt: new Date(),
    });

    logger.info(
      { orderId: String(order._id), status: 'COLLECTED' },
      'collect-complete',
    );

    return formatOrder(updated);
  }
}

module.exports = new CollectUnlockService();
