'use strict';

/**
 * Razorpay TEST MODE unit tests (no network required for HMAC).
 *
 * Covers:
 * - Missing keys → assertConfigured throws
 * - Live keys rejected
 * - HMAC signature success / failure
 */

const assert = require('assert');
const crypto = require('crypto');
const path = require('path');

function loadClientWithEnv(env) {
  const previous = { ...process.env };
  Object.keys(process.env).forEach((key) => {
    if (key.startsWith('RAZORPAY_')) delete process.env[key];
  });
  Object.assign(process.env, env);

  const resolved = path.resolve(__dirname, '../src/services/razorpay.client.js');
  delete require.cache[resolved];
  // eslint-disable-next-line import/no-dynamic-require, global-require
  const client = require(resolved);

  return {
    client,
    restore() {
      Object.keys(process.env).forEach((key) => {
        if (key.startsWith('RAZORPAY_')) delete process.env[key];
      });
      Object.assign(process.env, previous);
      delete require.cache[resolved];
    },
  };
}

function sign(secret, orderId, paymentId) {
  return crypto
    .createHmac('sha256', secret)
    .update(`${orderId}|${paymentId}`)
    .digest('hex');
}

async function run() {
  {
    const { client, restore } = loadClientWithEnv({
      RAZORPAY_KEY_ID: 'rzp_test_unitkey',
      RAZORPAY_KEY_SECRET: 'unit_secret_value',
    });
    try {
      const creds = client.getCredentials();
      assert.strictEqual(creds.keyId, 'rzp_test_unitkey');
      assert.strictEqual(creds.keySecret, 'unit_secret_value');
      const configured = client.assertConfigured();
      assert.strictEqual(configured.keyId, 'rzp_test_unitkey');
    } finally {
      restore();
    }
  }

  {
    const { client, restore } = loadClientWithEnv({
      RAZORPAY_KEY_ID: '',
      RAZORPAY_KEY_SECRET: '',
    });
    try {
      assert.throws(() => client.assertConfigured(), /not configured/i);
    } finally {
      restore();
    }
  }

  {
    const { client, restore } = loadClientWithEnv({
      RAZORPAY_KEY_ID: 'rzp_live_forbidden',
      RAZORPAY_KEY_SECRET: 'live_secret',
    });
    try {
      assert.throws(() => client.assertConfigured(), /TEST MODE|Live/i);
    } finally {
      restore();
    }
  }

  {
    const { client, restore } = loadClientWithEnv({
      RAZORPAY_KEY_ID: 'rzp_test_unitkey',
      RAZORPAY_KEY_SECRET: 'unit_secret_value',
    });
    try {
      const orderId = 'order_ABC';
      const paymentId = 'pay_XYZ';
      const good = sign('unit_secret_value', orderId, paymentId);
      assert.strictEqual(
        client.verifyPaymentSignature({
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: good,
        }),
        true,
      );
      assert.strictEqual(
        client.verifyPaymentSignature({
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: 'deadbeef',
        }),
        false,
      );
    } finally {
      restore();
    }
  }

  console.log('razorpay.unit OK');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
