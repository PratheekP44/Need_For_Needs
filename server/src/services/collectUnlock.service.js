'use strict';

const orderRepository = require('../repositories/order.repository');
const AppError = require('../utils/AppError');
const { formatOrder } = require('./order.service');
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
  if (auth.role !== 'admin' && String(order.user) !== String(auth.sub)) {
    throw new AppError('Forbidden', 403);
  }
}

function assertReadyForCollect(order) {
  if (!['READY_FOR_COLLECTION', 'PAYMENT_SUCCESS'].includes(order.status)) {
    throw new AppError(
      `Order is not ready for unlock (status=${order.status})`,
      400,
    );
  }
}

/**
 * Phase 20 — dynamic unlock info for Collect (no Unlock JWT).
 *
 * Returns order-sourced port, terminalNumber, and boxNumbers[] for the
 * firmware 4-byte unlock bitmap. Never hardcodes Port/Box/Terminal = 1.
 */
class CollectUnlockService {
  async getUnlockInfo(auth, orderId) {
    const order = await orderRepository.findByIdOrOrderNumberForUnlock(orderId);
    if (!order) {
      throw new AppError('Order not found', 404);
    }
    assertOwner(auth, order);
    assertReadyForCollect(order);

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
    };
  }

  /**
   * Mark order COLLECTED after successful BLE unlock on device.
   */
  async markCollected(auth, orderId) {
    const order = await orderRepository.findByIdOrOrderNumber(orderId);
    if (!order) {
      throw new AppError('Order not found', 404);
    }
    assertOwner(auth, order);

    if (order.status === 'COLLECTED') {
      return formatOrder(order);
    }

    assertReadyForCollect(order);

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
