'use strict';

/**
 * Repairs broken Item→Stock→Box→Locker mapping.
 *
 * - Deletes stock whose locker/box ObjectIds no longer resolve
 * - With --seed: creates a demo locker (8 boxes), item, and stock assignment
 *
 *   npm run repair:stock
 *   npm run repair:stock:seed
 */

const { loadEnv } = require('../src/config/env');
const logger = require('../src/config/logger');
const {
  connectDatabase,
  disconnectDatabase,
} = require('../src/database/connection');
require('../src/models');
const Stock = require('../src/models/Stock');
const Box = require('../src/models/Box');
const Locker = require('../src/models/Locker');
const Admin = require('../src/models/Admin');
const stockService = require('../src/services/stock.service');
const itemService = require('../src/services/item.service');
const lockerService = require('../src/services/locker.service');
const {
  deriveBoxOccupancyFromStock,
} = require('../src/utils/stockStatus');

async function repairBrokenRefs() {
  const stocks = await Stock.find({});
  let removed = 0;

  for (const stock of stocks) {
    const lockerOk = stock.locker
      ? Boolean(await Locker.exists({ _id: stock.locker }))
      : false;
    const boxOk = stock.box
      ? Boolean(await Box.exists({ _id: stock.box }))
      : false;

    if (!lockerOk || !boxOk) {
      await Stock.deleteOne({ _id: stock._id });
      removed += 1;
      logger.info(`Deleted broken stock ${stock.stockId}`, {
        lockerOk,
        boxOk,
      });
    }
  }

  logger.info(`Removed ${removed} broken stock record(s)`);
  return removed;
}

async function ensureDemoLocker(adminId) {
  // Prefer Campus Gate; never create a second demo locker if it exists.
  let locker =
    (await Locker.findOne({ lockerId: 'LCK-DEMO-06742' })) ||
    (await Locker.findOne({ status: 'ACTIVE' })) ||
    (await Locker.findOne());
  if (locker) {
    const boxCount = await Box.countDocuments({ locker: locker._id });
    if (boxCount > 0) return locker;
    logger.warn(`Locker ${locker.lockerId} has no boxes — creating a fresh demo locker`);
  }

  const stamp = Date.now().toString().slice(-5);
  locker = await lockerService.createLocker({
    lockerId: `LCK-DEMO-${stamp}`,
    lockerName: 'Campus Gate Locker',
    latitude: 12.9716,
    longitude: 77.5946,
    totalBoxes: 8,
    terminalNumber: 1,
    description: 'Demo locker for stock assignment',
    status: 'ACTIVE',
  });
  logger.info(`Created demo locker ${locker.lockerId || locker.id}`);
  return locker;
}

async function seedDemo(adminId) {
  const lockerDoc = await ensureDemoLocker(adminId);
  const lockerMongoId = lockerDoc.id || lockerDoc._id;

  const occupied = await Stock.distinct('box', { locker: lockerMongoId });
  const emptyBox = await Box.findOne({
    locker: lockerMongoId,
    _id: { $nin: occupied },
    status: { $nin: ['MAINTENANCE', 'FAULT', 'RESERVED'] },
  }).sort('boxNumber');

  if (!emptyBox) {
    logger.warn('No empty box available for seeding');
    return;
  }

  await Box.findByIdAndUpdate(emptyBox._id, {
    isEmpty: true,
    status: 'EMPTY',
  });

  const stamp = Date.now().toString().slice(-6);
  const item = await itemService.createItem(
    {
      itemId: `ITM-DEMO-${stamp}`,
      name: 'USB-C Cable',
      description: '1m braided USB-C cable for campus lockers',
      category: 'ELECTRONICS',
      brand: 'CampusEssentials',
      barcode: `8901${stamp}001`,
      sellingPrice: 199,
      costPrice: 90,
      gstPercentage: 18,
      unit: 'piece',
      tags: ['demo', 'cable'],
    },
    adminId,
  );

  const stock = await stockService.assignStock(
    {
      box: emptyBox._id,
      item: item.id,
      locker: lockerMongoId,
      // Unit-box model: exactly one item in this physical box.
      currentQuantity: 1,
      maximumQuantity: 1,
      reorderLevel: 0,
    },
    adminId,
  );

  logger.info('Seeded demo stock', {
    itemId: item.itemId,
    stockId: stock.stockId,
    lockerId: stock.lockerId,
    boxId: stock.boxId,
    boxNumber: stock.boxNumber,
    quantity: stock.quantity,
  });
}

async function syncOccupancy() {
  const remaining = await Stock.find({});
  for (const stock of remaining) {
    if (!stock.box) continue;
    const occupancy = deriveBoxOccupancyFromStock(stock);
    await Box.findByIdAndUpdate(stock.box, occupancy);
  }
}

async function main() {
  const config = loadEnv();
  await connectDatabase(config.mongoUri);
  await repairBrokenRefs();

  if (process.argv.includes('--seed')) {
    const admin = await Admin.findOne();
    await seedDemo(admin?._id || null);
  }

  await syncOccupancy();
  await disconnectDatabase();
  logger.info('Repair complete');
}

main().catch(async (error) => {
  logger.error('Repair failed', { message: error.message, stack: error.stack });
  try {
    await disconnectDatabase();
  } catch (_) {}
  process.exit(1);
});
