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
      name: 'P8 Admin',
      email: `p8.admin.${stamp}@campus.edu`,
      phone: `+9181${String(stamp).slice(-8)}`,
      password: 'Password1',
      accountType: 'admin',
    },
  });
  assert(admin.status === 201, `admin ${admin.status}`);
  const adminToken = admin.json.data.accessToken;

  const user = await request('POST', '/auth/signup', {
    body: {
      name: 'P8 User',
      email: `p8.user.${stamp}@campus.edu`,
      phone: `+9182${String(stamp).slice(-8)}`,
      password: 'Password1',
      accountType: 'user',
    },
  });
  assert(user.status === 201, `user ${user.status}`);
  const userToken = user.json.data.accessToken;

  const locker = await request('POST', '/lockers', {
    token: adminToken,
    body: {
      lockerId: `P8-${String(stamp).slice(-6)}`,
      lockerName: 'Phase8 Locker',
      latitude: 12.97,
      longitude: 77.59,
      status: 'ACTIVE',
      totalBoxes: 2,
      description: 'phase8',
    },
  });
  assert(locker.status === 201, `locker ${JSON.stringify(locker.json)}`);
  const lockerMongoId = locker.json.data.locker.id;
  const box1 = locker.json.data.locker.boxes[0].id;

  const item = await request('POST', '/items', {
    token: adminToken,
    body: {
      itemId: `ITM8-${String(stamp).slice(-6)}`,
      name: 'Gel Pen',
      description: 'Campus pen',
      category: 'STATIONERY',
      brand: 'WriteWell',
      barcode: `P8${stamp}`,
      sellingPrice: 25,
      costPrice: 10,
      gstPercentage: 18,
      unit: 'piece',
    },
  });
  assert(item.status === 201, `item ${JSON.stringify(item.json)}`);
  const itemId = item.json.data.item.id;

  const stock = await request('POST', '/stock', {
    token: adminToken,
    body: {
      stockId: `STK8-${String(stamp).slice(-6)}`,
      box: box1,
      item: itemId,
      currentQuantity: 10,
      maximumQuantity: 20,
      reorderLevel: 2,
    },
  });
  assert(stock.status === 201, `stock ${JSON.stringify(stock.json)}`);
  const stockId = stock.json.data.stock.id;
  const stockQtyBefore = stock.json.data.stock.currentQuantity;

  const added = await request('POST', '/cart/add', {
    token: userToken,
    body: { stockId, quantity: 3 },
  });
  assert(added.status === 200, `add cart ${JSON.stringify(added.json)}`);
  assert(added.json.data.cart.items.length === 1, 'expected 1 cart item');
  assert(added.json.data.cart.tax > 0, 'expected GST tax');
  const cartItemId = added.json.data.cart.items[0].id;

  const updated = await request('PUT', '/cart/update', {
    token: userToken,
    body: { cartItemId, quantity: 2 },
  });
  assert(updated.status === 200, 'update cart failed');
  assert(updated.json.data.cart.items[0].quantity === 2, 'qty should be 2');

  const checkout = await request('POST', '/checkout', {
    token: userToken,
    body: { discount: 0 },
  });
  assert(checkout.status === 201, `checkout ${JSON.stringify(checkout.json)}`);
  const order = checkout.json.data.order;
  assert(order.status === 'WAITING_PAYMENT', 'status waiting payment');
  assert(order.paymentStatus === 'PENDING', 'payment pending');
  assert(order.stockReserved === true, 'stock reserved');
  console.log('order', order.orderNumber, 'grandTotal', order.grandTotal);

  const stockAfter = await request('GET', `/stock/${stockId}`, { token: userToken });
  assert(
    stockAfter.json.data.stock.currentQuantity === stockQtyBefore - 2,
    'stock should be reserved/decremented',
  );

  const cartAfter = await request('GET', '/cart', { token: userToken });
  assert(cartAfter.json.data.cart.items.length === 0, 'cart should be empty after checkout');

  const listed = await request('GET', '/orders', { token: userToken });
  assert(listed.status === 200 && listed.json.data.orders.length >= 1, 'list orders');

  const cancelled = await request('PUT', `/orders/${order.id}/cancel`, {
    token: userToken,
  });
  assert(cancelled.status === 200, `cancel ${JSON.stringify(cancelled.json)}`);
  assert(cancelled.json.data.order.status === 'CANCELLED', 'cancelled');

  const stockReleased = await request('GET', `/stock/${stockId}`, { token: userToken });
  assert(
    stockReleased.json.data.stock.currentQuantity === stockQtyBefore,
    'stock should be released after cancel',
  );

  await request('DELETE', `/lockers/${lockerMongoId}`, { token: adminToken });
  // item may remain; stock removed with? stock still exists on deleted locker boxes?
  // locker delete removes boxes but not stock - might orphan. phase6 delete locker deletes boxes only.
  // For smoke cleanup try delete stock first if needed - locker already deleted.
  console.log('phase8_smoke_ok');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
