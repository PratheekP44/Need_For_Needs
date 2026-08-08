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

router.post(
  '/orders/:id/unlock-payload',
  authenticate,
  authorize('user', 'admin'),
  orderIdParamValidator,
  validate,
  orderController.issueUnlockPayload,
);

// Phase 17 — minimal unlock fields (no JWT). Collect uses this.
router.get(
  '/orders/:id/unlock-info',
  authenticate,
  authorize('user', 'admin'),
  orderIdParamValidator,
  validate,
  orderController.getUnlockInfo,
);

// Phase 17 — mark COLLECTED after successful BLE unlock.
router.post(
  '/orders/:id/collect-complete',
  authenticate,
  authorize('user', 'admin'),
  orderIdParamValidator,
  validate,
  orderController.collectComplete,
);

module.exports = router;
