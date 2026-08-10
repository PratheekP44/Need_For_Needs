'use strict';

/**
 * Phase 22 — AUDIT ONLY (no deletes).
 *
 * Lists all lockers and dependency counts, highlighting Campus Gate
 * (LCK-DEMO-06742) vs candidates for cleanup.
 *
 *   node scripts/audit-lockers-cleanup.js
 */

const { loadEnv } = require('../src/config/env');
const {
  connectDatabase,
  disconnectDatabase,
} = require('../src/database/connection');
require('../src/models');

const Locker = require('../src/models/Locker');
const BLEDevice = require('../src/models/BLEDevice');
const Box = require('../src/models/Box');
const Stock = require('../src/models/Stock');
const Order = require('../src/models/Order');
const Cart = require('../src/models/Cart');
const Payment = require('../src/models/Payment');
const Transaction = require('../src/models/Transaction');
const ActivityLog = require('../src/models/ActivityLog');
const Item = require('../src/models/Item');

const PROTECTED_LOCKER_ID = 'LCK-DEMO-06742';

async function auditOne(locker) {
  const id = locker._id;
  const ble = locker.BLEDevice
    ? await BLEDevice.findById(locker.BLEDevice).lean()
    : null;
  const boxCount = await Box.countDocuments({ locker: id });
  const stocks = await Stock.find({ locker: id }).select('item stockId').lean();
  const stockCount = stocks.length;
  const itemIds = [
    ...new Set(
      stocks
        .map((s) => (s.item ? String(s.item) : null))
        .filter(Boolean),
    ),
  ];
  const orderCount = await Order.countDocuments({ locker: id });
  const cartCount = await Cart.countDocuments({ 'items.locker': id });
  const paymentCount = await Payment.countDocuments({
    order: {
      $in: await Order.find({ locker: id }).distinct('_id'),
    },
  });
  const txCount = await Transaction.countDocuments({
    order: {
      $in: await Order.find({ locker: id }).distinct('_id'),
    },
  });
  const activityCount = await ActivityLog.countDocuments({
    entity: 'Locker',
    entityId: id,
  }).catch(() => 0);

  return {
    mongoId: String(id),
    lockerId: locker.lockerId,
    lockerName: locker.lockerName,
    terminalNumber: locker.terminalNumber,
    status: locker.status,
    totalBoxes: locker.totalBoxes,
    bleDeviceId: ble ? String(ble._id) : null,
    bleMac: ble?.macAddress || null,
    bleName: ble?.deviceName || null,
    boxCount,
    stockCount,
    itemIds,
    orderCount,
    cartCount,
    paymentCount,
    txCount,
    activityCount,
    protected: locker.lockerId === PROTECTED_LOCKER_ID,
  };
}

async function findExclusiveItems(candidateItemIds, protectLockerMongoId) {
  const exclusive = [];
  const shared = [];
  for (const itemId of candidateItemIds) {
    const elsewhere = await Stock.countDocuments({
      item: itemId,
      locker: { $ne: protectLockerMongoId },
    });
    const onCampus = await Stock.countDocuments({
      item: itemId,
      locker: protectLockerMongoId,
    });
    if (onCampus > 0) {
      shared.push(itemId);
    } else if (elsewhere === 0) {
      // Only on candidate lockers we're about to remove — check any stock left
      const any = await Stock.countDocuments({ item: itemId });
      if (any > 0) exclusive.push(itemId);
      else exclusive.push(itemId);
    } else {
      shared.push(itemId);
    }
  }
  return { exclusive, shared };
}

async function main() {
  const config = loadEnv();
  await connectDatabase(config.mongoUri);

  const lockers = await Locker.find({}).sort({ lockerId: 1 }).lean();
  console.log('\n=== LOCKER AUDIT (Phase 22) ===\n');
  console.log(`Total lockers: ${lockers.length}`);
  console.log(`Protected lockerId: ${PROTECTED_LOCKER_ID}\n`);

  const campus = lockers.find((l) => l.lockerId === PROTECTED_LOCKER_ID);
  if (!campus) {
    console.error('FATAL: Campus Gate LCK-DEMO-06742 NOT FOUND — abort.');
    process.exitCode = 2;
    await disconnectDatabase();
    return;
  }

  const reports = [];
  for (const locker of lockers) {
    const report = await auditOne(locker);
    reports.push(report);
  }

  for (const r of reports) {
    console.log('---');
    console.log(
      `${r.protected ? '[KEEP]' : '[CANDIDATE]'} ${r.lockerId} | ${r.lockerName}`,
    );
    console.log(`  mongoId: ${r.mongoId}`);
    console.log(`  terminalNumber: ${r.terminalNumber}`);
    console.log(`  status: ${r.status}`);
    console.log(`  BLE: ${r.bleName || '—'} / ${r.bleMac || '—'} (${r.bleDeviceId || 'none'})`);
    console.log(
      `  boxes=${r.boxCount} stock=${r.stockCount} orders=${r.orderCount} carts=${r.cartCount} payments=${r.paymentCount} tx=${r.txCount}`,
    );
    console.log(`  stock item ObjectIds: ${r.itemIds.length}`);
  }

  const protect = reports.find((r) => r.protected);
  const candidates = reports.filter((r) => !r.protected);
  const candidateItemIds = [
    ...new Set(candidates.flatMap((c) => c.itemIds)),
  ];

  const { exclusive, shared } = await findExclusiveItems(
    candidateItemIds,
    protect.mongoId,
  );

  console.log('\n=== SUMMARY ===');
  console.log(`Campus Gate: ${protect.lockerId} terminal=${protect.terminalNumber}`);
  console.log(`Candidates for deletion: ${candidates.length}`);
  candidates.forEach((c) =>
    console.log(`  - ${c.lockerId} (${c.lockerName})`),
  );
  console.log(`Items on candidate lockers only (exclusive): ${exclusive.length}`);
  console.log(`Items also on Campus Gate / shared: ${shared.length}`);

  // Orphan BLE devices not referenced by any locker
  const referencedBle = lockers
    .map((l) => l.BLEDevice)
    .filter(Boolean)
    .map(String);
  const orphanBle = await BLEDevice.find({
    _id: { $nin: referencedBle },
  })
    .select('deviceName macAddress')
    .lean();
  console.log(`Orphan BLEDevice (unreferenced): ${orphanBle.length}`);
  orphanBle.forEach((b) =>
    console.log(`  - ${b.deviceName} ${b.macAddress} ${b._id}`),
  );

  console.log('\nAudit complete — no deletions performed.\n');
  await disconnectDatabase();
}

main().catch(async (err) => {
  console.error(err);
  try {
    await disconnectDatabase();
  } catch (_) {}
  process.exit(1);
});
