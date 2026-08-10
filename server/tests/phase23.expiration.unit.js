'use strict';

/**
 * Phase 23 — order collection expiration unit tests (no Mongo / no network).
 *
 * Uses an injectable clock so we never wait 2 real hours.
 */

const assert = require('assert');
const path = require('path');

function loadExpiration() {
  const resolved = path.resolve(
    __dirname,
    '../src/services/orderExpiration.service.js',
  );
  delete require.cache[resolved];
  // eslint-disable-next-line import/no-dynamic-require, global-require
  return require(resolved);
}

function hoursFrom(base, hours) {
  return new Date(base.getTime() + hours * 60 * 60 * 1000);
}

async function run() {
  const {
    computeCollectionDeadline,
    expireOrderIfNeeded,
    assertCollectible,
    getCollectionWindowMs,
  } = loadExpiration();

  const paidAt = new Date('2026-08-10T12:00:00.000Z');

  // 1–3. Payment success window = paidAt + 2 hours
  {
    const deadline = computeCollectionDeadline(paidAt);
    assert.strictEqual(
      deadline.toISOString(),
      '2026-08-10T14:00:00.000Z',
      'collectionDeadline must be paidAt + 2h',
    );
    assert.strictEqual(getCollectionWindowMs(), 2 * 60 * 60 * 1000);
  }

  // 4. Pending before deadline remains collectible
  {
    const order = {
      status: 'READY_FOR_COLLECTION',
      paymentStatus: 'SUCCESS',
      paidAt,
      collectionDeadline: computeCollectionDeadline(paidAt),
    };
    const now = () => hoursFrom(paidAt, 1);
    await expireOrderIfNeeded(order, { now });
    assert.strictEqual(order.status, 'READY_FOR_COLLECTION');
    assert.doesNotThrow(() => assertCollectible(order, { now }));
  }

  // 5. Pending after deadline becomes EXPIRED
  {
    let persisted = null;
    const order = {
      _id: 'ord1',
      status: 'READY_FOR_COLLECTION',
      paymentStatus: 'SUCCESS',
      paidAt,
      collectionDeadline: computeCollectionDeadline(paidAt),
    };
    const now = () => hoursFrom(paidAt, 2 + 1 / 3600); // +2h +1s
    const updated = await expireOrderIfNeeded(order, {
      now,
      persist: async (id, data) => {
        persisted = { id, ...data };
        Object.assign(order, data);
        return order;
      },
    });
    assert.strictEqual(updated.status, 'EXPIRED');
    assert.ok(persisted.expiredAt);
    assert.strictEqual(persisted.status, 'EXPIRED');
  }

  // 6. Expired order cannot be collected
  {
    const order = {
      status: 'EXPIRED',
      paymentStatus: 'SUCCESS',
      paidAt,
      collectionDeadline: computeCollectionDeadline(paidAt),
      expiredAt: hoursFrom(paidAt, 2),
    };
    assert.throws(
      () => assertCollectible(order, { now: () => hoursFrom(paidAt, 3) }),
      /expired/i,
    );
  }

  // 7. Collected order does not expire
  {
    const order = {
      status: 'COLLECTED',
      paymentStatus: 'SUCCESS',
      paidAt,
      collectionDeadline: computeCollectionDeadline(paidAt),
      collectedAt: hoursFrom(paidAt, 0.5),
    };
    await expireOrderIfNeeded(order, { now: () => hoursFrom(paidAt, 5) });
    assert.strictEqual(order.status, 'COLLECTED');
  }

  // 8. Cancelled order does not expire
  {
    const order = {
      status: 'CANCELLED',
      paymentStatus: 'SUCCESS',
      paidAt,
      collectionDeadline: computeCollectionDeadline(paidAt),
      cancelledAt: hoursFrom(paidAt, 0.1),
    };
    await expireOrderIfNeeded(order, { now: () => hoursFrom(paidAt, 5) });
    assert.strictEqual(order.status, 'CANCELLED');
  }

  // 9. Pending payment order does not expire via collection helper
  {
    const order = {
      status: 'WAITING_PAYMENT',
      paymentStatus: 'PENDING',
      collectionDeadline: null,
    };
    await expireOrderIfNeeded(order, { now: () => hoursFrom(paidAt, 5) });
    assert.strictEqual(order.status, 'WAITING_PAYMENT');
    assert.throws(() => assertCollectible(order), /Payment not completed/i);
  }

  // 17–18. Device clock irrelevant; collection at/after deadline rejected
  {
    const order = {
      status: 'READY_FOR_COLLECTION',
      paymentStatus: 'SUCCESS',
      paidAt,
      collectionDeadline: computeCollectionDeadline(paidAt),
    };
    const exactlyAt = () => hoursFrom(paidAt, 2);
    assert.throws(() => assertCollectible(order, { now: exactlyAt }), /expired/i);

    const after = () => hoursFrom(paidAt, 2.5);
    assert.throws(() => assertCollectible(order, { now: after }), /expired/i);
  }

  // Missing deadline
  {
    const order = {
      status: 'READY_FOR_COLLECTION',
      paymentStatus: 'SUCCESS',
      paidAt,
      collectionDeadline: null,
    };
    assert.throws(
      () => assertCollectible(order, { now: () => hoursFrom(paidAt, 0.5) }),
      /deadline missing/i,
    );
  }

  // Already collected / cancelled messages
  {
    assert.throws(
      () => assertCollectible({ status: 'COLLECTED', paymentStatus: 'SUCCESS' }),
      /already collected/i,
    );
    assert.throws(
      () => assertCollectible({ status: 'CANCELLED', paymentStatus: 'SUCCESS' }),
      /cancelled/i,
    );
  }

  console.log('phase23.expiration.unit.js: all assertions passed');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
