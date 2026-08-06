'use strict';

const cartService = require('../services/cart.service');
const asyncHandler = require('../middlewares/asyncHandler');

const getCart = asyncHandler(async (req, res) => {
  const cart = await cartService.getCart(req.auth.sub);
  res.status(200).json({
    success: true,
    message: 'Cart fetched successfully',
    data: { cart },
  });
});

const addToCart = asyncHandler(async (req, res) => {
  const cart = await cartService.addItem(req.auth.sub, req.body);
  res.status(200).json({
    success: true,
    message: 'Item added to cart',
    data: { cart },
  });
});

const updateCartItem = asyncHandler(async (req, res) => {
  const cart = await cartService.updateItem(req.auth.sub, req.body);
  res.status(200).json({
    success: true,
    message: 'Cart item updated',
    data: { cart },
  });
});

const removeCartItem = asyncHandler(async (req, res) => {
  const cart = await cartService.removeItem(req.auth.sub, req.params.id);
  res.status(200).json({
    success: true,
    message: 'Cart item removed',
    data: { cart },
  });
});

const clearCart = asyncHandler(async (req, res) => {
  const cart = await cartService.clearCart(req.auth.sub);
  res.status(200).json({
    success: true,
    message: 'Cart cleared',
    data: { cart },
  });
});

module.exports = {
  getCart,
  addToCart,
  updateCartItem,
  removeCartItem,
  clearCart,
};
