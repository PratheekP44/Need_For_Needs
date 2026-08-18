'use strict';

/**
 * ONE-TIME Phase 40 — clear active item assignments on Campus Gate only.
 *
 * Does NOT delete: lockers, boxes, items, orders, users, payments, transactions.
 * Only removes Stock rows for Campus Gate and marks those boxes EMPTY.
 *
 * Dry-run (default):
 *   node scripts/reset-active-box-assignments.js
 *
 * Execute once:
 *   node scripts/reset-active-box-assignments.js --execute
 *
 * Not wired into server startup. Safe to keep; does nothing without --execute.
 */

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const { loadEnv } = require('../src/config/env');
const {
  connectDatabase,
  disconnectDatabase,
} = require('../src/database/connection');
require('../src/models');
const Locker = require('../src/models/Locker');
const Box = require('../src/models/Box');
const Stock = require('../src/models/Stock');
const logger = require('../src/config/logger');

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

  if (!campus) {
    logger.error('Campus Gate locker not found — aborting');
    await disconnectDatabase();
    process.exit(1);
  }

  const boxes = await Box.find({ locker: campus._id }).sort('boxNumber');
  const stocks = await Stock.find({ locker: campus._id })
    .populate('item', 'name')
    .populate('box', 'boxNumber');

  const maintainFault = boxes.filter((b) =>
    ['MAINTENANCE', 'FAULT'].includes(b.status),
  );

  logger.info('Campus Gate reset preview', {
    mode: EXECUTE ? 'EXECUTE' : 'DRY_RUN',
    lockerId: campus.lockerId,
    lockerName: campus.lockerName,
    totalBoxes: boxes.length,
    stockRowsToRemove: stocks.length,
    maintenanceOrFault: maintainFault.map((b) => b.boxNumber),
    assignments: stocks.map((s) => ({
      stockId: s.stockId,
      box: s.box?.boxNumber,
      qty: s.currentQuantity,
      item: s.item?.name,
    })),
  });

  if (!EXECUTE) {
    logger.warn('Dry-run only. Re-run with --execute to apply.');
    await disconnectDatabase();
    return;
  }

  const deleteResult = await Stock.deleteMany({ locker: campus._id });

  let emptied = 0;
  for (const box of boxes) {
    if (['MAINTENANCE', 'FAULT'].includes(box.status)) {
      continue;
    }
    // eslint-disable-next-line no-await-in-loop
    await Box.updateOne(
      { _id: box._id },
      { $set: { status: 'EMPTY', isEmpty: true } },
    );
    emptied += 1;
  }

  const remainingStocks = await Stock.countDocuments({ locker: campus._id });
  const emptyBoxes = await Box.countDocuments({
    locker: campus._id,
    isEmpty: true,
    status: 'EMPTY',
  });

  logger.info('Campus Gate reset complete', {
    stocksDeleted: deleteResult.deletedCount,
    boxesMarkedEmpty: emptied,
    remainingStocks,
    emptyBoxes,
    totalBoxes: boxes.length,
  });

  await disconnectDatabase();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
