'use strict';

/**
 * Smoke verification for stock → cart mapping + one-box-one-stock rules.
 * Usage: node scripts/verify-stock-cart.js
 * Requires server running on PORT (default 5000) and admin credentials.
 */

const BASE = process.env.API_BASE || 'http://127.0.0.1:5000';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'pratheekpreddy@gmail.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'Alpha001';

async function req(path, { method = 'GET', token, body } = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  return { status: res.status, json };
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

async function main() {
  console.log('Verifying against', BASE);

  const login = await req('/auth/login', {
    method: 'POST',
    body: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD },
  });
  assert(login.status === 200, `Admin login failed: ${login.status}`);
  const adminToken = login.json.data?.accessToken;
  assert(adminToken, 'Missing admin accessToken');

  const stockList = await req('/stock?limit=5&availability=available', {
    token: adminToken,
  });
  assert(stockList.status === 200, 'Stock list failed');
  const rows = stockList.json.data?.stock || [];
  console.log('Catalog rows:', rows.length);

  if (rows.length) {
    const row = rows[0];
    assert(row.stockId, 'stockId missing');
    assert(row.lockerId, `lockerId missing on ${row.stockId}`);
    assert(row.boxId, `boxId missing on ${row.stockId}`);
    assert(row.lockerName != null, 'lockerName missing');
    assert(row.boxNumber != null, 'boxNumber missing');
    assert(row.quantity != null, 'quantity missing');
    assert(row.availability, 'availability missing');
    assert(
      String(row.lockerId) !== 'null' && String(row.boxId) !== 'null',
      'Catalog must expose non-null lockerId/boxId for add-to-cart',
    );
    console.log('Sample catalog mapping OK', {
      stockId: row.stockId,
      lockerId: row.lockerId,
      boxId: row.boxId,
      quantity: row.quantity,
      availability: row.availability,
    });

    const occupiedBox = row.boxId;
    const items = await req('/items?limit=1', { token: adminToken });
    const item = (items.json.data?.items || [])[0];
    if (item && occupiedBox) {
      const dup = await req('/stock', {
        method: 'POST',
        token: adminToken,
        body: {
          box: occupiedBox,
          item: item.id,
          currentQuantity: 1,
          maximumQuantity: 5,
        },
      });
      assert(
        dup.status === 409,
        `Expected 409 for occupied box, got ${dup.status}`,
      );
      console.log('Occupied box protected OK');
    }
  } else {
    console.log('No available stock — assign stock in admin, then re-run');
  }

  const lockers = await req('/lockers?limit=1', { token: adminToken });
  const locker = (lockers.json.data?.lockers || [])[0];
  if (locker) {
    const empty = await req(
      `/boxes?locker=${locker.id}&unassigned=true&limit=100`,
      { token: adminToken },
    );
    assert(empty.status === 200, 'Empty boxes query failed');
    const boxes = empty.json.data?.boxes || [];
    console.log(`Unassigned boxes for ${locker.lockerName}: ${boxes.length}`);
  }

  console.log('Verification complete');
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
