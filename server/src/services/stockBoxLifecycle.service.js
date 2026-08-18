'use strict';

/**
 * Shared physical box ↔ stock lifecycle helpers.
 * Canonical rule: empty / assignable box === no Stock document.
 */

const Stock = require('../models/Stock');
const stockRepository = require('../repositories/stock.repository');
const boxRepository = require('../repositories/box.repository');
const {
  deriveBoxOccupancyFromStock,
} = require('../utils/stockStatus');

const HOLDING_ORDER_STATUSES = [
  'CREATED',
  'WAITING_PAYMENT',
  'PAYMENT_SUCCESS',
  'READY_FOR_COLLECTION',
];

async function syncBoxEmpty(boxDoc) {
  if (!boxDoc) return;
  if (boxDoc.status === 'MAINTENANCE' || boxDoc.status === 'FAULT') {
    return;
  }
  const occupancy = deriveBoxOccupancyFromStock(null);
  await boxRepository.updateById(boxDoc._id || boxDoc, occupancy);
}

/**
 * Delete a stock row and mark its box EMPTY (authoritative free).
 */
async function releaseStockRowAndFreeBox(stock) {
  if (!stock) return false;
  const boxId = stock.box?._id || stock.box;
  await stockRepository.deleteById(stock._id);
  if (boxId) {
    const box = await boxRepository.findById(boxId);
    await syncBoxEmpty(box);
  }
  return true;
}

async function isStockHeldByActiveOrderOrCart(stockId) {
  const Order = require('../models/Order');
  const Cart = require('../models/Cart');
  const [order, cart] = await Promise.all([
    Order.findOne({
      'items.stock': stockId,
      status: { $in: HOLDING_ORDER_STATUSES },
    })
      .select('_id')
      .lean()
      .exec(),
    Cart.findOne({
      status: 'ACTIVE',
      'items.stock': stockId,
    })
      .select('_id')
      .lean()
      .exec(),
  ]);
  return Boolean(order || cart);
}

/**
 * Remove zero-qty stock rows that are not held by cart/order.
 * Frees boxes so Inventory empty count == Assign available boxes.
 */
async function purgeOrphanZeroQtyStocks({ lockerId = null } = {}) {
  const filter = { currentQuantity: { $lte: 0 } };
  if (lockerId) {
    filter.locker = lockerId;
  }
  const stocks = await Stock.find(filter).select('_id box locker currentQuantity').exec();
  let freed = 0;
  for (const stock of stocks) {
    if (await isStockHeldByActiveOrderOrCart(stock._id)) {
      continue;
    }
    // eslint-disable-next-line no-await-in-loop
    const ok = await releaseStockRowAndFreeBox(stock);
    if (ok) freed += 1;
  }
  return freed;
}

/**
 * After successful collect-complete: free ONLY this order's stock rows.
 * Empty box === no Stock document. Historical order.items / boxes are kept.
 */
async function releaseStocksForCollectedOrder(order) {
  if (!order || !Array.isArray(order.items)) return 0;
  let freed = 0;
  const seen = new Set();

  for (const line of order.items) {
    let stock = null;
    const stockId = line.stock?._id || line.stock;
    if (stockId) {
      // eslint-disable-next-line no-await-in-loop
      stock = await stockRepository.findByIdOrStockId(stockId);
    }
    // Fallback: line.box still has a stock row (e.g. stale ObjectId).
    if (!stock) {
      const boxId = line.box?._id || line.box;
      if (boxId) {
        // eslint-disable-next-line no-await-in-loop
        stock = await stockRepository.findByBox(boxId);
      }
    }
    if (!stock) continue;
    const key = String(stock._id);
    if (seen.has(key)) continue;
    seen.add(key);
    // eslint-disable-next-line no-await-in-loop
    const ok = await releaseStockRowAndFreeBox(stock);
    if (ok) freed += 1;
  }
  return freed;
}

module.exports = {
  syncBoxEmpty,
  releaseStockRowAndFreeBox,
  purgeOrphanZeroQtyStocks,
  releaseStocksForCollectedOrder,
  isStockHeldByActiveOrderOrCart,
  HOLDING_ORDER_STATUSES,
};
