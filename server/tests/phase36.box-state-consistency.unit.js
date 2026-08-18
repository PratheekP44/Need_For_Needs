'use strict';

/**
 * Phase 36 — Inventory empty count === Assign available boxes.
 * Canonical: occupied = Stock row present (even qty 0 awaiting collection).
 */

const assert = require('assert');
const path = require('path');

function loadStockStatus() {
  const resolved = path.resolve(__dirname, '../src/utils/stockStatus.js');
  delete require.cache[resolved];
  // eslint-disable-next-line import/no-dynamic-require, global-require
  return require(resolved);
}

/**
 * Mirrors inventory + unassigned-box logic using the shared helpers.
 */
function inventoryAndAvailable({ boxes, stocks }) {
  const {
    isBoxPhysicallyOccupied,
    isBoxAssignableForStocking,
    summarizeLockerBoxState,
  } = loadStockStatus();

  const stockByBoxId = new Map();
  for (const stock of stocks) {
    const key = String(stock.box);
    if (!stockByBoxId.has(key)) stockByBoxId.set(key, stock);
  }

  const summary = summarizeLockerBoxState(boxes, stockByBoxId);
  const availableBoxNumbers = boxes
    .filter((box) =>
      isBoxAssignableForStocking(box, stockByBoxId.get(String(box._id))),
    )
    .map((box) => box.boxNumber)
    .sort((a, b) => a - b);

  const occupiedNumbers = boxes
    .filter((box) =>
      isBoxPhysicallyOccupied(stockByBoxId.get(String(box._id))),
    )
    .map((box) => box.boxNumber)
    .sort((a, b) => a - b);

  return { summary, availableBoxNumbers, occupiedNumbers };
}

function campusBoxes() {
  return Array.from({ length: 8 }, (_, i) => ({
    _id: `box-${i + 1}`,
    boxNumber: i + 1,
    status: 'EMPTY',
  }));
}

async function run() {
  // Case from Phase 36 §21: boxes 1–5 occupied → empty 6,7,8
  {
    const boxes = campusBoxes();
    const stocks = [1, 2, 3, 4, 5].map((n) => ({
      box: `box-${n}`,
      currentQuantity: 1,
      item: { name: `Item ${n}` },
    }));
    const result = inventoryAndAvailable({ boxes, stocks });
    assert.deepStrictEqual(result.summary, {
      totalBoxes: 8,
      occupiedBoxes: 5,
      emptyBoxes: 3,
    });
    assert.deepStrictEqual(result.availableBoxNumbers, [6, 7, 8]);
    assert.strictEqual(
      result.summary.emptyBoxes,
      result.availableBoxNumbers.length,
      'Inventory empty must equal Assign available count',
    );
  }

  // Qty-0 stock still occupies (awaiting collection) — must NOT look empty to Assign
  {
    const boxes = campusBoxes();
    const stocks = [
      { box: 'box-1', currentQuantity: 1, item: { name: 'A' } },
      { box: 'box-2', currentQuantity: 0, item: { name: 'B' } }, // held / awaiting
    ];
    const result = inventoryAndAvailable({ boxes, stocks });
    assert.strictEqual(result.summary.occupiedBoxes, 2);
    assert.strictEqual(result.summary.emptyBoxes, 6);
    assert.ok(!result.availableBoxNumbers.includes(2));
    assert.strictEqual(
      result.summary.emptyBoxes,
      result.availableBoxNumbers.length,
    );
  }

  // After assigning Box 6 → 6 occupied, available 7,8
  {
    const boxes = campusBoxes();
    const stocks = [1, 2, 3, 4, 5, 6].map((n) => ({
      box: `box-${n}`,
      currentQuantity: 1,
    }));
    const result = inventoryAndAvailable({ boxes, stocks });
    assert.deepStrictEqual(result.summary, {
      totalBoxes: 8,
      occupiedBoxes: 6,
      emptyBoxes: 2,
    });
    assert.deepStrictEqual(result.availableBoxNumbers, [7, 8]);
  }

  // After deleting Box 6 stock → available again 6,7,8
  {
    const boxes = campusBoxes();
    const stocks = [1, 2, 3, 4, 5].map((n) => ({
      box: `box-${n}`,
      currentQuantity: 1,
    }));
    const result = inventoryAndAvailable({ boxes, stocks });
    assert.deepStrictEqual(result.availableBoxNumbers, [6, 7, 8]);
    assert.strictEqual(result.summary.emptyBoxes, 3);
  }

  // MAINTENANCE boxes are not assignable (and not counted as empty for stocking)
  {
    const {
      isBoxAssignableForStocking,
      summarizeLockerBoxState,
    } = loadStockStatus();
    const boxes = [
      { _id: 'a', boxNumber: 1, status: 'EMPTY' },
      { _id: 'b', boxNumber: 2, status: 'MAINTENANCE' },
    ];
    const stockByBoxId = new Map();
    const summary = summarizeLockerBoxState(boxes, stockByBoxId);
    // Physical empty count still includes maintenance box (no stock).
    assert.strictEqual(summary.emptyBoxes, 2);
    assert.strictEqual(
      isBoxAssignableForStocking(boxes[1], null),
      false,
    );
    assert.strictEqual(
      isBoxAssignableForStocking(boxes[0], null),
      true,
    );
  }

  // Invariant: occupied + empty === total
  {
    const boxes = campusBoxes();
    const stocks = [
      { box: 'box-1', currentQuantity: 1 },
      { box: 'box-8', currentQuantity: 0 },
    ];
    const { summary } = inventoryAndAvailable({ boxes, stocks });
    assert.strictEqual(
      summary.occupiedBoxes + summary.emptyBoxes,
      summary.totalBoxes,
    );
  }

  console.log('phase36.box-state-consistency.unit.js: all assertions passed');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
