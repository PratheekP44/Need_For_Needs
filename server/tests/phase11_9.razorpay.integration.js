'use strict';

/**
 * Phase 11.9 — Real Razorpay Test Payment integration scenarios.
 *
 * Requires a running API on :5000 and valid Mongo.
 * Works with RAZORPAY_MOCK=true (offline) or false (official SDK + Test keys).
 *
 * Scenarios:
 * - Payment Success → READY_FOR_COLLECTION
 * - Invalid Signature → 400
 * - Duplicate Verification → 409
 * - Payment Failure path via /payment/fail
 * - Network / missing order → 404
 */

const http = require('http');
const crypto = require('crypto');

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
  throw new Error('Server not healthy on :5000');
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

function sign(orderId, paymentId) {
  const secret = process.env.RAZORPAY_KEY_SECRET || 'mock_secret';
  return crypto
    .createHmac('sha256', secret)
    .update(`${orderId}|${paymentId}`)
    .digest('hex');
}

async function seedCatalog(adminToken, stamp) {
  const locker = await request('POST', '/lockers', {
    token: adminToken,
    body: {
      lockerId: `LCK-P119-${stamp}`,
      lockerName: `Phase119 Locker ${stamp}`,
      latitude: 12.97,
      longitude: 77.59,
      totalBoxes: 2,
      status: 'ONLINE',
    },
  });
  assert(locker.status === 201, `locker ${JSON.stringify(locker.json)}`);
  const lockerMongoId = locker.json.data.locker.id;
  const boxId = locker.json.data.locker.boxes[0].id;

  const item = await request('POST', '/items', {
    token: adminToken,
    body: {
      itemId: `ITM-P119-${stamp}`,
      name: 'Phase119 Snack',
      description: 'integration',
      category: 'Snacks',
      brand: 'CE',
      barcode: `P119${stamp}`,
      sellingPrice: 50,
      costPrice: 20,
      gstPercentage: 5,
      unit: 'piece',
    },
  });
  assert(item.status === 201, `item ${JSON.stringify(item.json)}`);
  const itemMongoId = item.json.data.item.id;

  const stock = await request('POST', '/stock', {
    token: adminToken,
    body: {
      stockId: `STK-P119-${stamp}`,
      locker: lockerMongoId,
      box: boxId,
      item: itemMongoId,
      currentQuantity: 5,
      maximumQuantity: 20,
      reorderLevel: 1,
    },
  });
  assert(stock.status === 201, `stock ${JSON.stringify(stock.json)}`);
  return {
    lockerMongoId,
    stockId: stock.json.data.stock.stockId || stock.json.data.stock.id,
  };
}

async function main() {
  await waitForHealth();
  const stamp = Date.now();

  const admin = await request('POST', '/auth/signup', {
    body: {
      name: 'P119 Admin',
      email: `p119.admin.${stamp}@campus.edu`,
      phone: `+9185${String(stamp).slice(-8)}`,
      password: 'Password1',
      accountType: 'admin',
    },
  });
  assert(admin.status === 201, `admin ${admin.status}`);
  const adminToken = admin.json.data.accessToken;

  const user = await request('POST', '/auth/signup', {
    body: {
      name: 'P119 User',
      email: `p119.user.${stamp}@campus.edu`,
      phone: `+9186${String(stamp).slice(-8)}`,
      password: 'Password1',
      accountType: 'user',
    },
  });
  assert(user.status === 201, `user ${user.status}`);
  const userToken = user.json.data.accessToken;

  const { lockerMongoId, stockId } = await seedCatalog(adminToken, stamp);

  // --- Network failure style: missing order ---
  const missing = await request('POST', '/payment/create-order', {
    token: userToken,
    body: { orderId: '000000000000000000000000' },
  });
  assert(missing.status === 404, `missing order expected 404 got ${missing.status}`);

  // --- Happy path ---
  const add = await request('POST', '/cart/add', {
    token: userToken,
    body: { stockId, quantity: 1 },
  });
  assert(add.status === 200, `cart add ${JSON.stringify(add.json)}`);

  const checkout = await request('POST', '/checkout', {
    token: userToken,
    body: {},
  });
  assert(checkout.status === 201, `checkout ${JSON.stringify(checkout.json)}`);
  const order = checkout.json.data.order;

  const created = await request('POST', '/payment/create-order', {
    token: userToken,
    body: { orderId: order.id },
  });
  assert(created.status === 201, `create-order ${JSON.stringify(created.json)}`);
  assert(created.json.data.razorpay.currency === 'INR', 'currency INR');
  assert(created.json.data.razorpay.keyId, 'keyId returned for Flutter Checkout');
  assert(
    typeof created.json.data.razorpay.mock === 'boolean',
    'mock flag present',
  );

  const rzOrderId = created.json.data.razorpay.orderId;
  const payId = `pay_p119_${stamp}`;

  // Invalid signature
  const bad = await request('POST', '/payment/verify', {
    token: userToken,
    body: {
      razorpay_order_id: rzOrderId,
      razorpay_payment_id: payId,
      razorpay_signature: '00invalidsignature00',
    },
  });
  assert(bad.status === 400, `invalid signature ${bad.status}`);

  // Fresh create-order after invalid verify
  const created2 = await request('POST', '/payment/create-order', {
    token: userToken,
    body: { orderId: order.id },
  });
  assert(created2.status === 201, `create-order 2 ${JSON.stringify(created2.json)}`);
  const rzOrderId2 = created2.json.data.razorpay.orderId;
  const payId2 = `pay_p119_ok_${stamp}`;
  const signature = sign(rzOrderId2, payId2);

  // Success
  const verified = await request('POST', '/payment/verify', {
    token: userToken,
    body: {
      razorpay_order_id: rzOrderId2,
      razorpay_payment_id: payId2,
      razorpay_signature: signature,
      paymentMethod: 'upi',
    },
  });
  assert(verified.status === 200, `verify ${JSON.stringify(verified.json)}`);
  assert(verified.json.data.order.status === 'READY_FOR_COLLECTION', 'READY_FOR_COLLECTION');
  assert(verified.json.data.payment.status === 'SUCCESS', 'payment SUCCESS');

  // Duplicate verification
  const dup = await request('POST', '/payment/verify', {
    token: userToken,
    body: {
      razorpay_order_id: rzOrderId2,
      razorpay_payment_id: payId2,
      razorpay_signature: signature,
    },
  });
  assert(dup.status === 409, `duplicate ${dup.status}`);

  // User cancellation / failure equivalent: /payment/fail on a new order
  await request('POST', '/cart/add', {
    token: userToken,
    body: { stockId, quantity: 1 },
  });
  const checkout2 = await request('POST', '/checkout', {
    token: userToken,
    body: {},
  });
  assert(checkout2.status === 201, `checkout2 ${JSON.stringify(checkout2.json)}`);
  const fail = await request('POST', '/payment/fail', {
    token: userToken,
    body: {
      orderId: checkout2.json.data.order.id,
      reason: 'User cancelled Razorpay Checkout',
    },
  });
  assert(fail.status === 200, `fail ${JSON.stringify(fail.json)}`);
  assert(fail.json.data.order.status === 'CANCELLED', 'cancelled after fail');

  await request('DELETE', `/lockers/${lockerMongoId}`, { token: adminToken });

  console.log('phase11_9_razorpay_integration_ok', {
    mock: created.json.data.razorpay.mock,
    order: order.orderNumber,
    status: verified.json.data.order.status,
  });
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
