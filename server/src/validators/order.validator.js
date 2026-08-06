'use strict';

const { body, param, query } = require('express-validator');
const { ORDER_STATUSES, ORDER_PAYMENT_STATUSES } = require('../models/enums');

const checkoutValidator = [
  body('discount').optional().isFloat({ min: 0 }).toFloat(),
];

const orderIdParamValidator = [
  param('id').trim().notEmpty().withMessage('Order id is required'),
];

const listOrdersValidator = [
  query('page').optional().isInt({ min: 1 }).toInt(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  query('status').optional().isIn(ORDER_STATUSES),
  query('paymentStatus').optional().isIn(ORDER_PAYMENT_STATUSES),
  query('locker').optional().isMongoId(),
  query('user').optional().isMongoId(),
  query('search').optional().isString(),
  query('sort').optional().isString(),
];

module.exports = {
  checkoutValidator,
  orderIdParamValidator,
  listOrdersValidator,
};
