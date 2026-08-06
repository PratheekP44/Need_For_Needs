'use strict';

/**
 * Razorpay TEST MODE payment smoke (requires server on :5000 + .env keys).
 *
 * Covers:
 * - Checkout does NOT reduce inventory
 * - create-order hits Razorpay TEST API (order_*, rzp_test_*)
 * - Invalid signature rejected
 * - Valid HMAC verify assigns stock + CE1 token + transaction
 * - Idempotent re-verify
 * - Fail path cancels without stock release when never reserved
 */

const path = require('path');
const http = require('http');
const crypto = require('crypto');
require('dotenv').config({ path: path.join(__dirname, '../.env'), quiet: true });

function request(method, pathName, { token, body } = {}) {
  const payload = body ? JSON.stringify(body) : null;
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port: 5000,
        path: pathName,
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

function sign(orderId, paymentId) {
  const secret = String(process.env.RAZORPAY_KEY_SECRET || '').trim();
  assert(secret, 'RAZORPAY_KEY_SECRET must be set in server/.env');
  return crypto
    .createHmac('sha256', secret)
    .update(`${orderId}|${paymentId}`)
    .digest('hex');
}

async function main() {
  await waitForHealth();
  const stamp = Date.now();

  const admin = await request('POST', '/auth/signup', {
    body: {
      name: 'RP Admin',
      email: `rp.admin.${stamp}@campus.edu`,
      phone: `+9183${String(stamp).slice(-8)}`,
      password: 'Password1',
      accountType: 'admin',
    },
  });
  assert(admin.status === 201, `admin ${admin.status}`);
  const adminToken = admin.json.data.accessToken;

  const user = await request('POST', '/auth/signup', {
    body: {
      name: 'RP User',
      email: `rp.user.${stamp}@campus.edu`,
      phone: `+9184${String(stamp).slice(-8)}`,
      password: 'Password1',
      accountType: 'user',
    },
  });
  assert(user.status === 201, `user ${user.status}`);
  const userToken = user.json.data.accessToken;

  const locker = await request('POST', '/lockers', {
    token: adminToken,
    body: {
      lockerId: `RP-${String(stamp).slice(-6)}`,
      lockerName: 'Razorpay Test Locker',
      latitude: 12.97,
      longitude: 77.59,
      status: 'ACTIVE',
      totalBoxes: 2,
      description: 'razorpay-test',
    },
  });
  assert(locker.status === 201, `locker ${JSON.stringify(locker.json)}`);
  const lockerMongoId = locker.json.data.locker.id;
  const box1 = locker.json.data.locker.boxes[0].id;
  const box2 = locker.json.data.locker.boxes[1].id;
  const lockerCode = locker.json.data.locker.lockerId;

  const item = await request('POST', '/items', {
    token: adminToken,
    body: {
      itemId: `ITMRP-${String(stamp).slice(-6)}`,
      name: 'Test Cable',
      description: 'Type-C cable',
      category: 'ELECTRONICS',
      brand: 'CableCo',
      barcode: `RP${stamp}`,
      sellingPrice: 100,
      costPrice: 40,
      gstPercentage: 18,
      unit: 'piece',
    },
  });
  assert(item.status === 201, `item ${JSON.stringify(item.json)}`);
  const itemId = item.json.data.item.id;

  const stock = await request('POST', '/stock', {
    token: adminToken,
    body: {
      stockId: `STKRP-${String(stamp).slice(-6)}`,
      box: box1,
      item: itemId,
      currentQuantity: 1,
      maximumQuantity: 1,
      reorderLevel: 0,
    },
  });
  assert(stock.status === 201, `stock ${JSON.stringify(stock.json)}`);
  const stockId = stock.json.data.stock.id;
  const stockQtyBefore = stock.json.data.stock.currentQuantity;

  const added = await request('POST', '/cart/add', {
    token: userToken,
    body: { stockId, lockerId: lockerMongoId, boxId: box1, quantity: 1 },
  });
  assert(added.status === 200, `add cart ${JSON.stringify(added.json)}`);

  const checkout = await request('POST', '/checkout', {
    token: userToken,
    body: { discount: 0 },
  });
  assert(checkout.status === 201, `checkout ${JSON.stringify(checkout.json)}`);
  const order = checkout.json.data.order;
  assert(order.status === 'WAITING_PAYMENT', 'waiting payment');
  assert(order.stockReserved === false, 'stock must NOT be reserved at checkout');

  const stockAfterCheckout = await request('GET', `/stock/${stockId}`, {
    token: userToken,
  });
  assert(
    stockAfterCheckout.json.data.stock.currentQuantity === stockQtyBefore,
    'inventory must not change at checkout',
  );

  const created = await request('POST', '/payment/create-order', {
    token: userToken,
    body: { orderId: order.id },
  });
  assert(created.status === 201, `create-order ${JSON.stringify(created.json)}`);
  assert(created.json.data.payment.status === 'PENDING', 'payment pending');
  assert(created.json.data.razorpay.mock === false, 'mock must be false');
  assert(
    String(created.json.data.razorpay.keyId).startsWith('rzp_test_'),
    'TEST MODE keyId required',
  );
  assert(
    String(created.json.data.razorpay.orderId).startsWith('order_'),
    'Razorpay order id required',
  );
  assert(
    !String(created.json.data.razorpay.orderId).includes('mock'),
    'must not use mock order ids',
  );

  const rzOrderId = created.json.data.razorpay.orderId;
  const rzPaymentId = `pay_test_${stamp}`;

  const badVerify = await request('POST', '/payment/verify', {
    token: userToken,
    body: {
      razorpay_order_id: rzOrderId,
      razorpay_payment_id: rzPaymentId,
      razorpay_signature: 'deadbeef',
    },
  });
  assert(badVerify.status === 400, `expected invalid signature ${badVerify.status}`);

  // Reuse PENDING gateway order (retry-friendly create-order)
  const created2 = await request('POST', '/payment/create-order', {
    token: userToken,
    body: { orderId: order.id },
  });
  assert(created2.status === 201, `create-order retry ${JSON.stringify(created2.json)}`);
  const rzOrderId2 = created2.json.data.razorpay.orderId;
  const paymentId2 = created2.json.data.payment.id;
  const rzPaymentId2 = `pay_ok_${stamp}`;
  const signature = sign(rzOrderId2, rzPaymentId2);

  const verified = await request('POST', '/payment/verify', {
    token: userToken,
    body: {
      razorpay_order_id: rzOrderId2,
      razorpay_payment_id: rzPaymentId2,
      razorpay_signature: signature,
      paymentMethod: 'upi',
    },
  });
  assert(verified.status === 200, `verify ${JSON.stringify(verified.json)}`);
  assert(verified.json.data.payment.status === 'SUCCESS', 'payment success');
  assert(
    verified.json.data.order.status === 'READY_FOR_COLLECTION',
    'ready for collection',
  );
  assert(verified.json.data.order.paymentStatus === 'SUCCESS', 'order payment success');
  assert(verified.json.data.order.stockReserved === true, 'stock reserved after pay');
  assert(
    String(verified.json.data.order.collectionToken).startsWith('CE1.'),
    'CE1 collection token',
  );
  assert(verified.json.data.order.transactionId, 'transaction id');
  assert(verified.json.data.order.gatewayPaymentId === rzPaymentId2, 'gateway payment id');
  assert(
    String(verified.json.data.order.collectionToken).includes(lockerCode),
    'token includes locker',
  );

  const stockAfterPay = await request('GET', `/stock/${stockId}`, { token: userToken });
  assert(
    stockAfterPay.json.data.stock.currentQuantity === stockQtyBefore - 1,
    'inventory reduced only after verify',
  );

  // Idempotent re-verify
  const dup = await request('POST', '/payment/verify', {
    token: userToken,
    body: {
      razorpay_order_id: rzOrderId2,
      razorpay_payment_id: rzPaymentId2,
      razorpay_signature: signature,
    },
  });
  assert(dup.status === 200, `idempotent verify ${dup.status}`);
  assert(dup.json.data.payment.status === 'SUCCESS', 'idempotent success');

  const got = await request('GET', `/payment/${paymentId2}`, { token: userToken });
  assert(got.status === 200, `get payment ${got.status}`);
  assert(got.json.data.payment.gatewayPaymentId === rzPaymentId2, 'gateway payment id');

  const listed = await request('GET', '/payments', { token: userToken });
  assert(listed.status === 200 && listed.json.data.payments.length >= 1, 'list payments');
  assert(listed.json.data.razorpayMode === 'test', 'razorpayMode test');

  // Failure path: unpaid order cancel — no stock release needed
  const stock2 = await request('POST', '/stock', {
    token: adminToken,
    body: {
      stockId: `STKRP2-${String(stamp).slice(-6)}`,
      box: box2,
      item: itemId,
      currentQuantity: 1,
      maximumQuantity: 1,
      reorderLevel: 0,
    },
  });
  assert(stock2.status === 201, `stock2 ${JSON.stringify(stock2.json)}`);
  const stockId2 = stock2.json.data.stock.id;

  const added2 = await request('POST', '/cart/add', {
    token: userToken,
    body: { stockId: stockId2, lockerId: lockerMongoId, boxId: box2, quantity: 1 },
  });
  assert(added2.status === 200, `add cart 2 ${JSON.stringify(added2.json)}`);

  const checkout2 = await request('POST', '/checkout', {
    token: userToken,
    body: {},
  });
  assert(checkout2.status === 201, `checkout2 ${JSON.stringify(checkout2.json)}`);
  const order2 = checkout2.json.data.order;
  assert(order2.stockReserved === false, 'second checkout not reserved');

  const stockMid = await request('GET', `/stock/${stockId2}`, { token: userToken });
  const qtyMid = stockMid.json.data.stock.currentQuantity;

  const fail = await request('POST', '/payment/fail', {
    token: userToken,
    body: { orderId: order2.id, reason: 'smoke fail' },
  });
  assert(fail.status === 200, `fail ${JSON.stringify(fail.json)}`);
  assert(fail.json.data.order.paymentStatus === 'FAILED', 'paymentStatus failed');
  assert(fail.json.data.order.status === 'CANCELLED', 'order cancelled on fail');

  const stockAfterFail = await request('GET', `/stock/${stockId2}`, { token: userToken });
  assert(
    stockAfterFail.json.data.stock.currentQuantity === qtyMid,
    'stock unchanged after fail when never reserved',
  );

  const badOrder = await request('POST', '/payment/create-order', {
    token: userToken,
    body: { orderId: '000000000000000000000000' },
  });
  assert(badOrder.status === 404, `invalid order ${badOrder.status}`);

  await request('DELETE', `/lockers/${lockerMongoId}`, { token: adminToken });
  console.log('razorpay_test_mode_smoke_ok', {
    paymentId2,
    order: order.orderNumber,
    rzOrderId: rzOrderId2,
    collectionToken: verified.json.data.order.collectionToken,
    stockBefore: stockQtyBefore,
    stockAfterPay: stockAfterPay.json.data.stock.currentQuantity,
  });
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
