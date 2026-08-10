'use strict';

/**
 * Phase 22 — Remove Razorpay test lockers (idempotent).
 *
 * PROTECTED (never deleted):
 *   lockerId = LCK-DEMO-06742  (Campus Gate Locker)
 *
 * Targets (explicit IDs from audit 2026-08-10):
 *   RP-250833, RP-278675, RP-302855, RP-322981, RP-357816
 *   OR any locker whose lockerName is exactly "Razorpay Test Locker"
 *   and lockerId !== LCK-DEMO-06742
 *
 * Deletes per target locker (in order):
 *   Stock → Cart line items → Orders (+ Payments + Transactions)
 *   → ActivityLog(entity=Locker) → Boxes → Locker → orphan BLEDevice
 *
 * NEVER deletes Item documents (items are shared with Campus Gate).
 *
 * Usage:
 *   node scripts/cleanup-razorpay-test-lockers.js           # dry-run
 *   node scripts/cleanup-razorpay-test-lockers.js --execute # apply
 */

const { loadEnv } = require('../src/config/env');
const logger = require('../src/config/logger');
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

const PROTECTED_LOCKER_ID = 'LCK-DEMO-06742';

/** Explicit lockerIds from Phase 22 audit (safe to re-run if already gone). */
const EXPLICIT_TEST_LOCKER_IDS = Object.freeze([
  'RP-250833',
  'RP-278675',
  'RP-302855',
  'RP-322981',
  'RP-357816',
]);

const EXECUTE = process.argv.includes('--execute');

async function assertCampusGateIntact() {
  const campus = await Locker.findOne({ lockerId: PROTECTED_LOCKER_ID });
  if (!campus) {
    throw new Error(
      `PROTECTED locker ${PROTECTED_LOCKER_ID} not found — aborting cleanup`,
    );
  }
  if (Number(campus.terminalNumber) !== 1) {
    logger.warn(
      `Campus Gate terminalNumber is ${campus.terminalNumber} (expected 1) — not modifying`,
    );
  }
  return campus;
}

async function resolveTargets() {
  const byId = await Locker.find({
    lockerId: { $in: EXPLICIT_TEST_LOCKER_IDS },
  }).lean();

  const byName = await Locker.find({
    lockerName: 'Razorpay Test Locker',
    lockerId: { $ne: PROTECTED_LOCKER_ID },
  }).lean();

  const map = new Map();
  for (const l of [...byId, ...byName]) {
    if (l.lockerId === PROTECTED_LOCKER_ID) continue;
    map.set(String(l._id), l);
  }
  return [...map.values()];
}

async function removeCartLinesForLocker(lockerMongoId) {
  const carts = await Cart.find({ 'items.locker': lockerMongoId });
  let removedLines = 0;
  for (const cart of carts) {
    const before = cart.items.length;
    cart.items = cart.items.filter(
      (line) => String(line.locker) !== String(lockerMongoId),
    );
    removedLines += before - cart.items.length;
    if (EXECUTE) {
      await cart.save();
    }
  }
  return removedLines;
}

async function cleanupLocker(locker, stats) {
  const id = locker._id;
  const label = `${locker.lockerId} (${locker.lockerName})`;

  if (locker.lockerId === PROTECTED_LOCKER_ID) {
    logger.error(`Refusing to delete protected locker ${label}`);
    return;
  }

  const orderIds = await Order.find({ locker: id }).distinct('_id');
  const stockCount = await Stock.countDocuments({ locker: id });
  const boxCount = await Box.countDocuments({ locker: id });
  const paymentCount = await Payment.countDocuments({ order: { $in: orderIds } });
  const txCount = await Transaction.countDocuments({ order: { $in: orderIds } });
  const activityCount = await ActivityLog.countDocuments({
    entity: 'Locker',
    entityId: id,
  });
  const cartLines = await removeCartLinesForLocker(id);

  logger.info(
    `${EXECUTE ? 'DELETE' : 'DRY-RUN'} ${label} | stock=${stockCount} boxes=${boxCount} orders=${orderIds.length} payments=${paymentCount} tx=${txCount} activity=${activityCount} cartLines=${cartLines}`,
  );

  if (!EXECUTE) {
    stats.dryRun.push(label);
    return;
  }

  const stockRes = await Stock.deleteMany({ locker: id });
  stats.stock += stockRes.deletedCount || 0;

  if (orderIds.length) {
    const txRes = await Transaction.deleteMany({ order: { $in: orderIds } });
    stats.transactions += txRes.deletedCount || 0;
    const payRes = await Payment.deleteMany({ order: { $in: orderIds } });
    stats.payments += payRes.deletedCount || 0;
    const ordRes = await Order.deleteMany({ _id: { $in: orderIds } });
    stats.orders += ordRes.deletedCount || 0;
  }

  const actRes = await ActivityLog.deleteMany({
    entity: 'Locker',
    entityId: id,
  });
  stats.activityLogs += actRes.deletedCount || 0;

  const boxRes = await Box.deleteMany({ locker: id });
  stats.boxes += boxRes.deletedCount || 0;

  const bleId = locker.BLEDevice;
  await Locker.deleteOne({ _id: id });
  stats.lockers += 1;

  if (bleId) {
    const stillUsed = await Locker.exists({ BLEDevice: bleId });
    if (!stillUsed) {
      const bleRes = await BLEDevice.deleteOne({ _id: bleId });
      stats.bleDevices += bleRes.deletedCount || 0;
    }
  }

  stats.cartLines += cartLines;
  stats.deleted.push(label);
}

async function verifyAfter() {
  const campus = await assertCampusGateIntact();
  const remainingRp = await Locker.find({
    $or: [
      { lockerId: { $in: EXPLICIT_TEST_LOCKER_IDS } },
      { lockerName: 'Razorpay Test Locker' },
    ],
  }).lean();
  const stillRp = remainingRp.filter(
    (l) => l.lockerId !== PROTECTED_LOCKER_ID,
  );

  const campusBoxes = await Box.countDocuments({ locker: campus._id });
  const campusStock = await Stock.countDocuments({ locker: campus._id });
  const campusBle = campus.BLEDevice
    ? await BLEDevice.findById(campus.BLEDevice).lean()
    : null;

  console.log('\n=== POST-CLEANUP VERIFICATION ===');
  console.log(
    `Campus Gate: ${campus.lockerId} | terminal=${campus.terminalNumber} | boxes=${campusBoxes} | stock=${campusStock}`,
  );
  console.log(
    `Campus BLE: ${campusBle?.deviceName || '—'} / ${campusBle?.macAddress || '—'}`,
  );
  console.log(`Remaining Razorpay test lockers: ${stillRp.length}`);
  if (stillRp.length) {
    stillRp.forEach((l) => console.log(`  STILL PRESENT: ${l.lockerId}`));
  }

  const allLockers = await Locker.find({}).select('lockerId lockerName').lean();
  console.log(`Total lockers now: ${allLockers.length}`);
  allLockers.forEach((l) =>
    console.log(`  - ${l.lockerId} | ${l.lockerName}`),
  );

  return stillRp.length === 0;
}

async function main() {
  const config = loadEnv();
  await connectDatabase(config.mongoUri);

  console.log(
    `\nPhase 22 cleanup — mode: ${EXECUTE ? 'EXECUTE' : 'DRY-RUN (pass --execute to apply)'}\n`,
  );

  await assertCampusGateIntact();
  const targets = await resolveTargets();

  if (!targets.length) {
    console.log('No Razorpay test lockers found — nothing to delete.');
    await verifyAfter();
    await disconnectDatabase();
    return;
  }

  console.log(`Targets (${targets.length}):`);
  targets.forEach((t) =>
    console.log(`  - ${t.lockerId} | ${t.lockerName} | terminal=${t.terminalNumber}`),
  );

  const stats = {
    dryRun: [],
    deleted: [],
    lockers: 0,
    boxes: 0,
    stock: 0,
    orders: 0,
    payments: 0,
    transactions: 0,
    activityLogs: 0,
    bleDevices: 0,
    cartLines: 0,
  };

  for (const locker of targets) {
    await cleanupLocker(locker, stats);
  }

  console.log('\n=== STATS ===');
  console.log(JSON.stringify(stats, null, 2));
  console.log('\nItems: NEVER deleted (shared with Campus Gate).');

  const ok = await verifyAfter();
  if (EXECUTE && !ok) {
    process.exitCode = 2;
  }

  await disconnectDatabase();
}

main().catch(async (err) => {
  console.error(err);
  try {
    await disconnectDatabase();
  } catch (_) {}
  process.exit(1);
});
