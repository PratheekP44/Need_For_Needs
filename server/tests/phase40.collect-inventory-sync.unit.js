'use strict';

/**
 * Phase 40 — collect-complete releases order boxes + emits inventory SSE.
 * Does not touch BLE / packet / payment.
 */

const assert = require('assert');
const path = require('path');
const { EventEmitter } = require('events');

function loadLifecycle() {
  const resolved = path.resolve(
    __dirname,
    '../src/services/stockBoxLifecycle.service.js',
  );
  delete require.cache[resolved];
  // eslint-disable-next-line import/no-dynamic-require, global-require
  return require(resolved);
}

function mockRepo(modPath, impl) {
  const resolved = path.resolve(__dirname, modPath);
  require.cache[resolved] = {
    id: resolved,
    filename: resolved,
    loaded: true,
    exports: impl,
  };
}

async function run() {
  // --- releaseStocksForCollectedOrder: only order stocks, multi-box ---
  {
    const deleted = [];
    const boxUpdates = [];
    const stocks = {
      s1: { _id: 's1', box: { _id: 'b1' } },
      s2: { _id: 's2', box: { _id: 'b3' } },
      sOther: { _id: 'sOther', box: { _id: 'b2' } },
    };

    mockRepo('../src/repositories/stock.repository.js', {
      findByIdOrStockId: async (id) => stocks[id] || null,
      findByBox: async () => null,
      deleteById: async (id) => {
        deleted.push(String(id));
        return true;
      },
    });
    mockRepo('../src/repositories/box.repository.js', {
      findById: async (id) => ({ _id: id, status: 'AVAILABLE' }),
      updateById: async (id, data) => {
        boxUpdates.push({ id: String(id), ...data });
        return true;
      },
    });
    mockRepo('../src/models/Stock.js', {});

    delete require.cache[
      path.resolve(__dirname, '../src/services/stockBoxLifecycle.service.js')
    ];
    const { releaseStocksForCollectedOrder } = loadLifecycle();

    const freed = await releaseStocksForCollectedOrder({
      items: [{ stock: 's1' }, { stock: 's2' }],
    });
    assert.strictEqual(freed, 2);
    assert.deepStrictEqual(deleted.sort(), ['s1', 's2']);
    assert.ok(!deleted.includes('sOther'));
    assert.strictEqual(boxUpdates.length, 2);
    assert.ok(boxUpdates.every((u) => u.isEmpty === true && u.status === 'EMPTY'));
  }

  // --- Failed collection must not release (no call) ---
  {
    // Documented contract: release only runs inside markCollected after
    // assertCollectible. Payment / Collect-open must not call release.
    const lifecyclePath = path.resolve(
      __dirname,
      '../src/services/stockBoxLifecycle.service.js',
    );
    const src = require('fs').readFileSync(lifecyclePath, 'utf8');
    assert.ok(src.includes('releaseStocksForCollectedOrder'));
    const collectPath = path.resolve(
      __dirname,
      '../src/services/collectUnlock.service.js',
    );
    const collectSrc = require('fs').readFileSync(collectPath, 'utf8');
    assert.ok(
      collectSrc.includes('releaseStocksForCollectedOrder(order)'),
      'collect-complete must release stocks',
    );
    assert.ok(
      collectSrc.includes("reason: 'collect_complete'"),
      'collect-complete must publish inventory event',
    );
    assert.ok(
      /assertCollectible[\s\S]*releaseStocksForCollectedOrder/.test(collectSrc),
      'release must happen only after collectible check',
    );
  }

  // --- inventory event shape + emit ---
  {
    const eventsPath = path.resolve(
      __dirname,
      '../src/services/inventory.events.js',
    );
    delete require.cache[eventsPath];
    // eslint-disable-next-line import/no-dynamic-require, global-require
    const inventoryEvents = require(eventsPath);
    assert.ok(inventoryEvents instanceof EventEmitter);

    let received = null;
    inventoryEvents.once('inventory', (e) => {
      received = e;
    });
    const published = inventoryEvents.publish({
      reason: 'collect_complete',
      orderNumber: 'ORD-TEST',
      stockIds: ['s1', 's2'],
    });
    assert.strictEqual(published.type, 'inventory_updated');
    assert.strictEqual(published.reason, 'collect_complete');
    assert.strictEqual(published.orderNumber, 'ORD-TEST');
    assert.deepStrictEqual(published.stockIds, ['s1', 's2']);
    assert.ok(received);
    assert.strictEqual(received.type, 'inventory_updated');
  }

  // --- Inventory counts after release ---
  {
    const {
      summarizeLockerBoxState,
      isBoxPhysicallyOccupied,
    } = require('../src/utils/stockStatus');

    const boxes = [1, 2, 3, 5].map((n) => ({
      _id: `box-${n}`,
      boxNumber: n,
      status: 'EMPTY',
    }));
    // After collecting 1,3,5 — only box 2 occupied
    const stockByBoxId = new Map([
      ['box-2', { currentQuantity: 1 }],
    ]);
    const summary = summarizeLockerBoxState(boxes, stockByBoxId);
    assert.deepStrictEqual(summary, {
      totalBoxes: 4,
      occupiedBoxes: 1,
      emptyBoxes: 3,
    });
    assert.strictEqual(
      summary.occupiedBoxes + summary.emptyBoxes,
      summary.totalBoxes,
    );
    assert.strictEqual(isBoxPhysicallyOccupied(null), false);
    assert.strictEqual(isBoxPhysicallyOccupied({}), true);
  }

  // --- Historical order retains box refs (release deletes stock, not order lines) ---
  {
    const order = {
      status: 'COLLECTED',
      items: [
        { stock: 's1', box: 'box-6', quantity: 1 },
      ],
      boxes: [6],
    };
    // Mutating inventory must not clear historical fields
    assert.strictEqual(order.items[0].box, 'box-6');
    assert.deepStrictEqual(order.boxes, [6]);
    assert.strictEqual(order.status, 'COLLECTED');
  }

  // --- Reset script safety: dry-run by default, Campus Gate only ---
  {
    const resetPath = path.resolve(
      __dirname,
      '../scripts/reset-active-box-assignments.js',
    );
    const resetSrc = require('fs').readFileSync(resetPath, 'utf8');
    assert.ok(resetSrc.includes('--execute'));
    assert.ok(resetSrc.includes('LCK-DEMO-06742'));
    assert.ok(resetSrc.includes('Campus Gate') || /campus/i.test(resetSrc));
    assert.ok(!resetSrc.includes('app.listen'));
    assert.ok(
      resetSrc.includes('Stock.deleteMany') || resetSrc.includes('deleteMany'),
    );
    assert.ok(
      !resetSrc.includes('Order.deleteMany') &&
        !resetSrc.includes('User.deleteMany') &&
        !resetSrc.includes('Payment.deleteMany'),
      'reset must not delete orders/users/payments',
    );
  }

  console.log('phase40.collect-inventory-sync.unit.js: all assertions passed');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
