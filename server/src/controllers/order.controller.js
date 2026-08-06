'use strict';

const orderService = require('../services/order.service');
const asyncHandler = require('../middlewares/asyncHandler');

const checkout = asyncHandler(async (req, res) => {
  const order = await orderService.checkout(req.auth.sub, req.body || {});
  res.status(201).json({
    success: true,
    message: 'Checkout successful. Order created (payment pending).',
    data: { order },
  });
});

const listOrders = asyncHandler(async (req, res) => {
  const data = await orderService.listOrders(req.auth, req.query);
  res.status(200).json({
    success: true,
    message: 'Orders fetched successfully',
    data,
  });
});

const getOrder = asyncHandler(async (req, res) => {
  const order = await orderService.getOrder(req.auth, req.params.id);
  res.status(200).json({
    success: true,
    message: 'Order fetched successfully',
    data: { order },
  });
});

const cancelOrder = asyncHandler(async (req, res) => {
  const order = await orderService.cancelOrder(req.auth, req.params.id);
  res.status(200).json({
    success: true,
    message: 'Order cancelled successfully',
    data: { order },
  });
});

module.exports = {
  checkout,
  listOrders,
  getOrder,
  cancelOrder,
};
