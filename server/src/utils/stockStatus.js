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
 * Canonical physical occupancy: a box is occupied iff a Stock row exists.
 * (One box → one stock. Qty 0 still occupies until the row is removed.)
 */
function isBoxPhysicallyOccupied(stock) {
  return Boolean(stock);
}

/**
 * Maps stock occupancy to Box physical flags.
 * A box with any stock record is occupied (one box → one stock),
 * even when quantity is zero. Does not override MAINTENANCE / FAULT.
 */
function deriveBoxOccupancyFromStock(stock) {
  if (!isBoxPhysicallyOccupied(stock)) {
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

/**
 * Admin stocking: box can receive a new stock row.
 * Same rules as GET /boxes?unassigned=true and inventory empty count.
 */
function isBoxAssignableForStocking(box, stock) {
  if (!box) return false;
  if (['MAINTENANCE', 'FAULT', 'RESERVED'].includes(box.status)) {
    return false;
  }
  return !isBoxPhysicallyOccupied(stock);
}

/**
 * Build locker summary from box list + stock-by-box map.
 * occupied + empty = total (invariant).
 */
function summarizeLockerBoxState(boxes, stockByBoxId) {
  const totalBoxes = boxes.length;
  let occupiedBoxes = 0;
  for (const box of boxes) {
    const stock = stockByBoxId.get(String(box._id || box.id));
    if (isBoxPhysicallyOccupied(stock)) occupiedBoxes += 1;
  }
  return {
    totalBoxes,
    occupiedBoxes,
    emptyBoxes: totalBoxes - occupiedBoxes,
  };
}

module.exports = {
  deriveStockStatus,
  deriveBoxOccupancyFromStock,
  isBoxPhysicallyOccupied,
  isBoxAssignableForStocking,
  summarizeLockerBoxState,
};
