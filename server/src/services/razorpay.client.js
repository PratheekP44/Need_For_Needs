'use strict';

const crypto = require('crypto');
const Razorpay = require('razorpay');
const AppError = require('../utils/AppError');
const logger = require('../config/logger');

/**
 * Razorpay TEST MODE client.
 *
 * Credentials come ONLY from server/.env:
 *   RAZORPAY_KEY_ID
 *   RAZORPAY_KEY_SECRET
 *
 * Mock gateway paths are removed. Flutter never receives the Key Secret.
 */
function getCredentials() {
  const keyId = String(process.env.RAZORPAY_KEY_ID || '').trim();
  const keySecret = String(process.env.RAZORPAY_KEY_SECRET || '').trim();
  return { keyId, keySecret };
}

function assertConfigured() {
  const { keyId, keySecret } = getCredentials();

  if (!keyId || !keySecret) {
    throw new AppError(
      'Razorpay TEST MODE is not configured. Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET in server/.env',
      503,
    );
  }

  if (keyId.startsWith('rzp_live_')) {
    throw new AppError(
      'Live Razorpay keys are not allowed in this build — use rzp_test_* TEST MODE keys',
      503,
    );
  }

  return { keyId, keySecret };
}

function createClient() {
  const { keyId, keySecret } = assertConfigured();
  return new Razorpay({
    key_id: keyId,
    key_secret: keySecret,
  });
}

async function createRazorpayOrder({ amountPaise, currency, receipt, notes }) {
  const { keyId } = assertConfigured();
  const instance = createClient();
  const payload = {
    amount: amountPaise,
    currency: currency || 'INR',
    receipt: String(receipt).slice(0, 40),
    notes: notes || {},
  };

  try {
    const razorpayOrder = await instance.orders.create(payload);
    logger.info('Razorpay TEST order created', {
      id: razorpayOrder.id,
      amount: razorpayOrder.amount,
      currency: razorpayOrder.currency,
    });
    return {
      razorpayOrder,
      keyId,
      mock: false,
    };
  } catch (err) {
    logger.error('Razorpay order create failed', {
      message: err.message,
      statusCode: err.statusCode,
      description: err.error?.description,
    });
    throw new AppError(
      err.error?.description || err.message || 'Failed to create Razorpay order',
      err.statusCode && err.statusCode >= 400 && err.statusCode < 600
        ? err.statusCode
        : 502,
    );
  }
}

/**
 * Verifies Razorpay Checkout signature (HMAC SHA256).
 * body = `${razorpay_order_id}|${razorpay_payment_id}`
 */
function verifyPaymentSignature({
  razorpayOrderId,
  razorpayPaymentId,
  razorpaySignature,
}) {
  const { keySecret } = assertConfigured();
  const body = `${razorpayOrderId}|${razorpayPaymentId}`;
  const expected = crypto.createHmac('sha256', keySecret).update(body).digest('hex');

  const provided = String(razorpaySignature || '');
  const expectedBuf = Buffer.from(expected, 'utf8');
  const providedBuf = Buffer.from(provided, 'utf8');

  if (expectedBuf.length !== providedBuf.length) {
    return false;
  }

  try {
    return crypto.timingSafeEqual(expectedBuf, providedBuf);
  } catch {
    return false;
  }
}

function toPaise(amountRupees) {
  return Math.round(Number(amountRupees) * 100);
}

module.exports = {
  createRazorpayOrder,
  verifyPaymentSignature,
  toPaise,
  getCredentials,
  assertConfigured,
  createClient,
};
