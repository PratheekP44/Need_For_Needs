'use strict';

const { body, param, query } = require('express-validator');
const { PAYMENT_STATUSES, PAYMENT_GATEWAYS } = require('../models/enums');

const createPaymentOrderValidator = [
  body('orderId').trim().notEmpty().withMessage('orderId is required'),
];

const verifyPaymentValidator = [
  body('razorpay_order_id')
    .trim()
    .notEmpty()
    .withMessage('razorpay_order_id is required'),
  body('razorpay_payment_id')
    .trim()
    .notEmpty()
    .withMessage('razorpay_payment_id is required'),
  body('razorpay_signature')
    .trim()
    .notEmpty()
    .withMessage('razorpay_signature is required'),
  body('paymentMethod').optional().isString().isLength({ max: 64 }),
];

const failPaymentValidator = [
  body('orderId').trim().notEmpty().withMessage('orderId is required'),
  body('reason').optional().isString().isLength({ max: 500 }),
];

const paymentIdParamValidator = [
  param('id').trim().notEmpty().withMessage('Payment id is required').isMongoId(),
];

const refundPaymentValidator = [
  param('id').trim().notEmpty().withMessage('Payment id is required').isMongoId(),
  body('note').optional().isString().isLength({ max: 500 }),
];

const listPaymentsValidator = [
  query('page').optional().isInt({ min: 1 }).toInt(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  query('status').optional().isIn(PAYMENT_STATUSES),
  query('gateway').optional().isIn(PAYMENT_GATEWAYS),
  query('order').optional().isMongoId(),
  query('user').optional().isMongoId(),
  query('search').optional().isString(),
  query('sort').optional().isString(),
];

module.exports = {
  createPaymentOrderValidator,
  verifyPaymentValidator,
  failPaymentValidator,
  paymentIdParamValidator,
  refundPaymentValidator,
  listPaymentsValidator,
};
