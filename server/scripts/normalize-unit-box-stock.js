'use strict';

/**
 * Phase 24 — normalize any legacy stock rows with quantity > 1.
 *
 * Does NOT invent extra box assignments. If a stock had quantity 4 in one box,
 * it becomes quantity 1 in that same box (physical unit-box model).
 *
 * Usage:
 *   node scripts/normalize-unit-box-stock.js
 *   node scripts/normalize-unit-box-stock.js --execute
 */

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const { loadEnv } = require('../src/config/env');
const {
  connectDatabase,
  disconnectDatabase,
} = require('../src/database/connection');
const logger = require('../src/config/logger');
require('../src/models');
const Stock = require('../src/models/Stock');
const Box = require('../src/models/Box');
const Locker = require('../src/models/Locker');
const { deriveBoxOccupancyFromStock } = require('../src/utils/stockStatus');

const EXECUTE = process.argv.includes('--execute');

async function main() {
  const config = loadEnv();
  await connectDatabase(config.mongoUri);

  const campus = await Locker.findOne({
    $or: [
      { lockerId: 'LCK-DEMO-06742' },
      { lockerName: /campus\s*gate/i },
    ],
  });

  if (campus) {
    const boxes = await Box.find({ locker: campus._id }).sort('boxNumber');
    const stocks = await Stock.find({ locker: campus._id })
      .populate('item', 'name')
      .populate('box', 'boxNumber');
    logger.info('Campus Gate snapshot', {
      lockerId: campus.lockerId,
      lockerName: campus.lockerName,
      totalBoxes: boxes.length,
      stockRows: stocks.length,
      assignments: stocks.map((s) => ({
        item: s.item?.name || String(s.item),
        box: s.box?.boxNumber,
        qty: s.currentQuantity,
        max: s.maximumQuantity,
      })),
    });
  } else {
    logger.warn('Campus Gate locker not found');
  }

  const bad = await Stock.find({
    $or: [
      { currentQuantity: { $gt: 1 } },
      { maximumQuantity: { $gt: 1 } },
    ],
  })
    .populate('item', 'name')
    .populate('box', 'boxNumber boxId')
    .populate('locker', 'lockerId lockerName');

  logger.info(`Found ${bad.length} stock row(s) with quantity/max > 1`);

  for (const stock of bad) {
    const previous = Number(stock.currentQuantity) || 0;
    logger.info('Normalize candidate', {
      stockId: stock.stockId,
      item: stock.item?.name,
      locker: stock.locker?.lockerName || stock.locker?.lockerId,
      box: stock.box?.boxNumber,
      currentQuantity: stock.currentQuantity,
      maximumQuantity: stock.maximumQuantity,
      action: EXECUTE
        ? previous > 0
          ? 'SET qty=1, max=1 (same box — no extra boxes created)'
          : 'SET max=1; qty stays 0 (then empty cleanup may delete)'
        : 'dry-run',
    });

    if (!EXECUTE) continue;

    // Inflated qty on one box → still one physical unit in that box.
    stock.currentQuantity = previous > 0 ? 1 : 0;
    stock.maximumQuantity = 1;
    if (Number(stock.reorderLevel) > 1) stock.reorderLevel = 0;
    await stock.save();

    if (stock.box) {
      await Box.findByIdAndUpdate(
        stock.box._id || stock.box,
        deriveBoxOccupancyFromStock(stock.currentQuantity > 0 ? stock : null),
      );
    }
  }

  // Zero-qty stock rows still unique-index the box and block assignment.
  // Physical model: empty box = no stock record.
  const zeroQty = await Stock.find({ currentQuantity: { $lte: 0 } })
    .populate('item', 'name')
    .populate('box', 'boxNumber');
  logger.info(`Found ${zeroQty.length} zero-quantity stock row(s) to clear`);
  for (const stock of zeroQty) {
    logger.info('Empty stock cleanup', {
      stockId: stock.stockId,
      item: stock.item?.name,
      box: stock.box?.boxNumber,
      action: EXECUTE ? 'DELETE stock + mark box EMPTY' : 'dry-run',
    });
    if (!EXECUTE) continue;
    const boxId = stock.box?._id || stock.box;
    await Stock.deleteOne({ _id: stock._id });
    if (boxId) {
      await Box.findByIdAndUpdate(boxId, { isEmpty: true, status: 'EMPTY' });
    }
  }

  // Remove Empty Box fake items if any were created historically.
  const Item = require('../src/models/Item');
  const fakeEmpty = await Item.find({
    name: { $regex: /^\s*empty\s*box\s*$/i },
  });
  if (fakeEmpty.length) {
    logger.warn('Found fake Empty Box item records (not deleted automatically)', {
      count: fakeEmpty.length,
      ids: fakeEmpty.map((i) => i.itemId || i._id),
    });
  }

  if (!EXECUTE) {
    logger.info('Dry-run only. Re-run with --execute to apply quantity fixes.');
  } else {
    logger.info('Normalization complete.');
  }

  await disconnectDatabase();
}

main().catch(async (error) => {
  logger.error('normalize-unit-box-stock failed', {
    message: error.message,
    stack: error.stack,
  });
  try {
    await disconnectDatabase();
  } catch (_) {}
  process.exit(1);
});
