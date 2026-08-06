'use strict';

const http = require('http');

function request(method, path, { token, body } = {}) {
  const payload = body ? JSON.stringify(body) : null;
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port: 5000,
        path,
        method,
        headers: {
          ...(payload
            ? {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload),
              }
            : {}),
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => {
          let json = {};
          try {
            json = JSON.parse(data || '{}');
          } catch {
            json = { raw: data };
          }
          resolve({ status: res.statusCode, json });
        });
      },
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function waitForHealth() {
  for (let i = 0; i < 40; i += 1) {
    try {
      const res = await request('GET', '/health');
      if (res.status === 200) return;
    } catch {
      // retry
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error('Server not healthy');
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

async function main() {
  await waitForHealth();
  const stamp = Date.now();

  const admin = await request('POST', '/auth/signup', {
    body: {
      name: 'P7 Admin',
      email: `p7.admin.${stamp}@campus.edu`,
      phone: `+9191${String(stamp).slice(-8)}`,
      password: 'Password1',
      accountType: 'admin',
    },
  });
  assert(admin.status === 201, `admin signup ${admin.status}`);
  const adminToken = admin.json.data.accessToken;

  const user = await request('POST', '/auth/signup', {
    body: {
      name: 'P7 User',
      email: `p7.user.${stamp}@campus.edu`,
      phone: `+9192${String(stamp).slice(-8)}`,
      password: 'Password1',
      accountType: 'user',
    },
  });
  const userToken = user.json.data.accessToken;

  const locker = await request('POST', '/lockers', {
    token: adminToken,
    body: {
      lockerId: `P7-${String(stamp).slice(-6)}`,
      lockerName: 'Phase7 Locker',
      latitude: 12.97,
      longitude: 77.59,
      status: 'ACTIVE',
      totalBoxes: 2,
      description: 'phase7',
    },
  });
  assert(locker.status === 201, `locker create ${locker.status} ${JSON.stringify(locker.json)}`);
  const lockerId = locker.json.data.locker.id;
  const box1 = locker.json.data.locker.boxes[0].id;
  const box2 = locker.json.data.locker.boxes[1].id;

  const item = await request('POST', '/items', {
    token: adminToken,
    body: {
      itemId: `ITM-${String(stamp).slice(-6)}`,
      name: 'Cold Brew',
      description: 'Campus cold brew can',
      category: 'BEVERAGE',
      brand: 'CampusSip',
      barcode: `BC${stamp}`,
      sellingPrice: 80,
      costPrice: 40,
      gstPercentage: 12,
      unit: 'can',
      tags: ['drink'],
    },
  });
  assert(item.status === 201, `item create ${item.status} ${JSON.stringify(item.json)}`);
  const itemId = item.json.data.item.id;
  console.log('item_created', item.json.data.item.itemId);

  const forbidden = await request('POST', '/items', {
    token: userToken,
    body: {
      itemId: 'X',
      name: 'Nope',
      description: 'x',
      category: 'FOOD',
      brand: 'x',
      barcode: 'x',
      sellingPrice: 1,
      costPrice: 1,
    },
  });
  assert(forbidden.status === 403, 'user cannot create item');

  const stock = await request('POST', '/stock', {
    token: adminToken,
    body: {
      stockId: `STK-${String(stamp).slice(-6)}`,
      box: box1,
      item: itemId,
      currentQuantity: 4,
      maximumQuantity: 10,
      reorderLevel: 5,
    },
  });
  assert(stock.status === 201, `stock assign ${stock.status} ${JSON.stringify(stock.json)}`);
  assert(stock.json.data.stock.status === 'LOW_STOCK', 'expected LOW_STOCK');
  console.log('stock_status', stock.json.data.stock.status);

  const boxAfter = await request('GET', `/boxes/${box1}`, { token: userToken });
  assert(boxAfter.json.data.box.isEmpty === false, 'box should not be empty');
  assert(boxAfter.json.data.box.status === 'AVAILABLE', 'box should be AVAILABLE');

  const restocked = await request('POST', `/stock/${stock.json.data.stock.id}/restock`, {
    token: adminToken,
    body: { addQuantity: 4 },
  });
  assert(restocked.status === 200, 'restock failed');
  assert(restocked.json.data.stock.status === 'IN_STOCK', 'expected IN_STOCK');
  assert(restocked.json.data.stock.currentQuantity === 8, 'qty should be 8');

  const moved = await request('POST', `/stock/${stock.json.data.stock.id}/move`, {
    token: adminToken,
    body: { toBox: box2 },
  });
  assert(moved.status === 200, `move failed ${JSON.stringify(moved.json)}`);

  const sourceBox = await request('GET', `/boxes/${box1}`, { token: userToken });
  const targetBox = await request('GET', `/boxes/${box2}`, { token: userToken });
  assert(sourceBox.json.data.box.isEmpty === true, 'source empty');
  assert(targetBox.json.data.box.isEmpty === false, 'target occupied');

  const low = await request('PUT', `/stock/${stock.json.data.stock.id}`, {
    token: adminToken,
    body: { currentQuantity: 0 },
  });
  assert(low.json.data.stock.status === 'OUT_OF_STOCK', 'expected OUT_OF_STOCK');

  const listed = await request('GET', '/items?category=BEVERAGE&sort=newest', {
    token: userToken,
  });
  assert(listed.status === 200, 'list items failed');

  const removed = await request('DELETE', `/stock/${stock.json.data.stock.id}`, {
    token: adminToken,
  });
  assert(removed.status === 200, 'remove stock failed');

  const deletedItem = await request('DELETE', `/items/${itemId}`, {
    token: adminToken,
  });
  assert(deletedItem.status === 200, 'delete item failed');

  await request('DELETE', `/lockers/${lockerId}`, { token: adminToken });
  console.log('phase7_smoke_ok');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
