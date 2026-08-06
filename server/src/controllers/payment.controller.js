'use strict';

const paymentService = require('../services/payment.service');
const asyncHandler = require('../middlewares/asyncHandler');

const createOrder = asyncHandler(async (req, res) => {
  const data = await paymentService.createOrder(req.auth, req.body || {});
  res.status(201).json({
    success: true,
    message: 'Razorpay order created successfully',
    data,
  });
});

const verify = asyncHandler(async (req, res) => {
  const data = await paymentService.verify(req.auth, req.body || {});
  res.status(200).json({
    success: true,
    message: 'Payment verified successfully. Order ready for collection.',
    data,
  });
});

const fail = asyncHandler(async (req, res) => {
  const data = await paymentService.fail(req.auth, req.body || {});
  res.status(200).json({
    success: true,
    message: 'Payment marked failed. Reserved stock released.',
    data,
  });
});

const getById = asyncHandler(async (req, res) => {
  const payment = await paymentService.getById(req.auth, req.params.id);
  res.status(200).json({
    success: true,
    message: 'Payment fetched successfully',
    data: { payment },
  });
});

const list = asyncHandler(async (req, res) => {
  const data = await paymentService.list(req.auth, req.query);
  res.status(200).json({
    success: true,
    message: 'Payments fetched successfully',
    data,
  });
});

const refund = asyncHandler(async (req, res) => {
  const data = await paymentService.refundPlaceholder(req.auth, req.params.id, req.body || {});
  res.status(200).json({
    success: true,
    message: data.message,
    data: { payment: data.payment },
  });
});

module.exports = {
  createOrder,
  verify,
  fail,
  getById,
  list,
  refund,
};
