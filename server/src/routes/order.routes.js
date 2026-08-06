'use strict';

const express = require('express');
const orderController = require('../controllers/order.controller');
const {
  checkoutValidator,
  orderIdParamValidator,
  listOrdersValidator,
} = require('../validators/order.validator');
const validate = require('../middlewares/validate');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

const router = express.Router();

router.post(
  '/checkout',
  authenticate,
  authorize('user'),
  checkoutValidator,
  validate,
  orderController.checkout,
);

router.get(
  '/orders',
  authenticate,
  authorize('user', 'admin'),
  listOrdersValidator,
  validate,
  orderController.listOrders,
);

router.get(
  '/orders/:id',
  authenticate,
  authorize('user', 'admin'),
  orderIdParamValidator,
  validate,
  orderController.getOrder,
);

router.put(
  '/orders/:id/cancel',
  authenticate,
  authorize('user', 'admin'),
  orderIdParamValidator,
  validate,
  orderController.cancelOrder,
);

module.exports = router;
