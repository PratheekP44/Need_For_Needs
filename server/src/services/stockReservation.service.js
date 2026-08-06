'use strict';

const stockRepository = require('../repositories/stock.repository');
const boxRepository = require('../repositories/box.repository');
const activityService = require('./activity.service');
const AppError = require('../utils/AppError');
const {
  deriveStockStatus,
  deriveBoxOccupancyFromStock,
} = require('../utils/stockStatus');

async function refreshStockDerivedFields(stockDoc) {
  if (!stockDoc) return null;

  const status = deriveStockStatus({
    currentQuantity: stockDoc.currentQuantity,
    reorderLevel: stockDoc.reorderLevel,
    expiryDate: stockDoc.expiryDate,
    currentStatus: stockDoc.status === 'DISABLED' ? 'DISABLED' : stockDoc.status,
  });

  const updated = await stockRepository.updateById(stockDoc._id, { status });
  const boxId = stockDoc.box?._id || stockDoc.box || updated?.box?._id || updated?.box;
  if (boxId) {
    const box = await boxRepository.findById(boxId);
    if (box && box.status !== 'MAINTENANCE' && box.status !== 'FAULT') {
      const occupancy = deriveBoxOccupancyFromStock(updated || stockDoc);
      await boxRepository.updateById(box._id, occupancy);
    }
  }
  return updated;
}

/**
 * Reserve stock quantities for checkout (does not use Stock HTTP APIs).
 */
async function reserveStockForLines(lines, { userId = null, orderNumber = null } = {}) {
  const reserved = [];

  try {
    for (const line of lines) {
      const stockId = line.stock?._id || line.stock;
      const updated = await stockRepository.reserveQuantity(stockId, line.quantity);
      if (!updated) {
        throw new AppError(
          `Insufficient or unavailable stock for item quantity ${line.quantity}`,
          409,
        );
      }
      await refreshStockDerivedFields(updated);
      reserved.push({ stockId, quantity: line.quantity });

      await activityService.log({
        action: 'stock_reserve',
        entity: 'Stock',
        entityId: stockId,
        userId,
        metadata: { quantity: line.quantity, orderNumber },
      });
    }
    return reserved;
  } catch (error) {
    // rollback any successful reservations
    for (const entry of reserved.reverse()) {
      const released = await stockRepository.releaseQuantity(entry.stockId, entry.quantity);
      await refreshStockDerivedFields(released);
    }
    throw error;
  }
}

async function releaseStockForLines(lines, { userId = null, orderNumber = null, reason = 'release' } = {}) {
  for (const line of lines) {
    const stockId = line.stock?._id || line.stock;
    const quantity = line.quantity;
    const updated = await stockRepository.releaseQuantity(stockId, quantity);
    await refreshStockDerivedFields(updated);
    await activityService.log({
      action: 'stock_release',
      entity: 'Stock',
      entityId: stockId,
      userId,
      metadata: { quantity, orderNumber, reason },
    });
  }
}

module.exports = {
  reserveStockForLines,
  releaseStockForLines,
  refreshStockDerivedFields,
};
