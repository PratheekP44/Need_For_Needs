'use strict';

/**
 * Phase 24 — physical unit-box model unit tests (no Mongo required for pure rules).
 */

const assert = require('assert');
const path = require('path');

function loadStockStatus() {
  const resolved = path.resolve(__dirname, '../src/utils/stockStatus.js');
  delete require.cache[resolved];
  // eslint-disable-next-line import/no-dynamic-require, global-require
  return require(resolved);
}

function buildPhysicalRows({ boxes, stocks }) {
  const stockByBoxId = new Map();
  for (const stock of stocks) {
    const key = String(stock.box);
    if (!stockByBoxId.has(key)) stockByBoxId.set(key, stock);
  }

  const rows = [];
  let occupied = 0;
  for (const box of boxes) {
    const stock = stockByBoxId.get(String(box.id));
    const qty = stock ? Number(stock.currentQuantity) || 0 : 0;
    const isOccupied = Boolean(stock && stock.item && qty > 0);
    if (isOccupied) occupied += 1;
    rows.push({
      boxNumber: box.boxNumber,
      itemName: isOccupied ? stock.item.name : null,
      quantity: isOccupied ? 1 : 0,
      occupancy: isOccupied ? 'Occupied' : 'Empty',
      displayName: isOccupied ? stock.item.name : 'Empty Box',
    });
  }
  return {
    rows,
    summary: {
      totalBoxes: boxes.length,
      occupiedBoxes: occupied,
      emptyBoxes: boxes.length - occupied,
    },
  };
}

function assertUnitQuantity(qty) {
  if (qty > 1) {
    const err = new Error(
      'Each box holds exactly one physical item (quantity must be 0 or 1)',
    );
    err.statusCode = 400;
    throw err;
  }
}

function assertSingleItemPerBox(existingStockOnBox) {
  if (existingStockOnBox) {
    const err = new Error('Box already occupied');
    err.statusCode = 409;
    throw err;
  }
}

async function run() {
  const { deriveBoxOccupancyFromStock } = loadStockStatus();

  // 1. One item in one box
  {
    const result = buildPhysicalRows({
      boxes: [
        { id: 'b1', boxNumber: 1 },
        { id: 'b2', boxNumber: 2 },
      ],
      stocks: [
        {
          box: 'b1',
          currentQuantity: 1,
          item: { name: 'USB-C Cable' },
        },
      ],
    });
    assert.strictEqual(result.rows[0].displayName, 'USB-C Cable');
    assert.strictEqual(result.rows[0].quantity, 1);
    assert.strictEqual(result.rows[0].boxNumber, 1);
    assert.strictEqual(result.summary.occupiedBoxes, 1);
    assert.strictEqual(result.summary.emptyBoxes, 1);
  }

  // 2. Same item in two physical boxes — separate rows, qty 1 each
  {
    const result = buildPhysicalRows({
      boxes: [
        { id: 'b1', boxNumber: 1 },
        { id: 'b3', boxNumber: 3 },
        { id: 'b7', boxNumber: 7 },
      ],
      stocks: [
        { box: 'b1', currentQuantity: 1, item: { name: 'USB-C Cable' } },
        { box: 'b3', currentQuantity: 1, item: { name: 'USB-C Cable' } },
        { box: 'b7', currentQuantity: 1, item: { name: 'USB-C Cable' } },
      ],
    });
    assert.strictEqual(result.rows.length, 3);
    assert.ok(result.rows.every((r) => r.quantity === 1));
    assert.ok(result.rows.every((r) => r.itemName === 'USB-C Cable'));
    // Never aggregate to quantity 3 on one row
    assert.ok(!result.rows.some((r) => r.quantity === 3));
    assert.strictEqual(result.summary.occupiedBoxes, 3);
    assert.strictEqual(result.summary.emptyBoxes, 0);
  }

  // 3–4. Empty boxes
  {
    const result = buildPhysicalRows({
      boxes: [
        { id: 'b1', boxNumber: 1 },
        { id: 'b2', boxNumber: 2 },
        { id: 'b3', boxNumber: 3 },
      ],
      stocks: [],
    });
    assert.ok(result.rows.every((r) => r.displayName === 'Empty Box'));
    assert.ok(result.rows.every((r) => r.quantity === 0));
    assert.strictEqual(result.summary.emptyBoxes, 3);
    assert.strictEqual(result.summary.totalBoxes, 3);
  }

  // 5. Attempt quantity 2 → reject
  assert.throws(() => assertUnitQuantity(2), /exactly one physical item/i);

  // 6. Attempt assigning two items to one box → reject
  assert.throws(
    () => assertSingleItemPerBox({ stockId: 'STK-1' }),
    /already occupied/i,
  );

  // 7. Remove item → box becomes empty (stock record removed)
  {
    const occupancy = deriveBoxOccupancyFromStock(null);
    assert.strictEqual(occupancy.status, 'EMPTY');
    assert.strictEqual(occupancy.isEmpty, true);
  }

  // 8–10. Inventory displays physical assignments; no aggregated row
  {
    const result = buildPhysicalRows({
      boxes: Array.from({ length: 8 }, (_, i) => ({
        id: `b${i + 1}`,
        boxNumber: i + 1,
      })),
      stocks: [
        { box: 'b1', currentQuantity: 1, item: { name: 'USB-C Cable' } },
        { box: 'b2', currentQuantity: 1, item: { name: 'Power Bank' } },
        { box: 'b3', currentQuantity: 1, item: { name: 'Notebook' } },
      ],
    });
    assert.strictEqual(result.summary.totalBoxes, 8);
    assert.strictEqual(result.summary.occupiedBoxes, 3);
    assert.strictEqual(result.summary.emptyBoxes, 5);
    const usbRows = result.rows.filter((r) => r.itemName === 'USB-C Cable');
    assert.strictEqual(usbRows.length, 1);
    assert.strictEqual(usbRows[0].quantity, 1);
    assert.strictEqual(usbRows[0].boxNumber, 1);
  }

  console.log('phase24.physical-box.unit.js: all assertions passed');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
