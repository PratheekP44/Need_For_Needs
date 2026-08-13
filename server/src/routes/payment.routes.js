'use strict';

const express = require('express');
const paymentController = require('../controllers/payment.controller');
const {
  createPaymentOrderValidator,
  verifyPaymentValidator,
  failPaymentValidator,
  paymentIdParamValidator,
  refundPaymentValidator,
  listPaymentsValidator,
} = require('../validators/payment.validator');
const validate = require('../middlewares/validate');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

const paymentRouter = express.Router();
const paymentsRouter = express.Router();

paymentRouter.post(
  '/create-order',
  authenticate,
  authorize('user'),
  createPaymentOrderValidator,
  validate,
  paymentController.createOrder,
);

paymentRouter.post(
  '/verify',
  authenticate,
  authorize('user', 'admin'),
  verifyPaymentValidator,
  validate,
  paymentController.verify,
);

paymentRouter.post(
  '/fail',
  authenticate,
  authorize('user', 'admin'),
  failPaymentValidator,
  validate,
  paymentController.fail,
);

paymentRouter.post(
  '/:id/refund',
  authenticate,
  authorize('admin'),
  refundPaymentValidator,
  validate,
  paymentController.refund,
);

paymentRouter.get(
  '/:id',
  authenticate,
  authorize('user', 'admin'),
  paymentIdParamValidator,
  validate,
  paymentController.getById,
);

paymentsRouter.get(
  '/',
  authenticate,
  authorize('user', 'admin'),
  listPaymentsValidator,
  validate,
  paymentController.list,
);

module.exports = {
  paymentRouter,
  paymentsRouter,
};
