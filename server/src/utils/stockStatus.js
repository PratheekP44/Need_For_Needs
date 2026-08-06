'use strict';

/**
 * Derives stock status from quantity / reorder / expiry rules.
 * DISABLED is preserved unless explicitly overridden by caller.
 */
function deriveStockStatus({
  currentQuantity,
  reorderLevel,
  expiryDate,
  currentStatus,
}) {
  if (currentStatus === 'DISABLED') {
    return 'DISABLED';
  }

  if (expiryDate && new Date(expiryDate).getTime() < Date.now()) {
    return 'EXPIRED';
  }

  const qty = Number(currentQuantity) || 0;
  const reorder = Number(reorderLevel) || 0;

  if (qty <= 0) {
    return 'OUT_OF_STOCK';
  }

  if (qty <= reorder) {
    return 'LOW_STOCK';
  }

  return 'IN_STOCK';
}

/**
 * Maps stock occupancy to Box physical flags.
 * A box with any stock record is occupied (one box → one stock),
 * even when quantity is zero. Does not override MAINTENANCE / FAULT.
 */
function deriveBoxOccupancyFromStock(stock) {
  if (!stock) {
    return {
      isEmpty: true,
      status: 'EMPTY',
    };
  }

  return {
    isEmpty: false,
    status: 'AVAILABLE',
  };
}

module.exports = {
  deriveStockStatus,
  deriveBoxOccupancyFromStock,
};
