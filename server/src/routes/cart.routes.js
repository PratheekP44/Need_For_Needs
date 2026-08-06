'use strict';

const express = require('express');
const cartController = require('../controllers/cart.controller');
const {
  addToCartValidator,
  updateCartValidator,
  removeCartItemValidator,
} = require('../validators/cart.validator');
const validate = require('../middlewares/validate');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(authenticate, authorize('user'));

router.get('/', cartController.getCart);
router.post('/add', addToCartValidator, validate, cartController.addToCart);
router.put('/update', updateCartValidator, validate, cartController.updateCartItem);
router.delete(
  '/remove/:id',
  removeCartItemValidator,
  validate,
  cartController.removeCartItem,
);
router.delete('/clear', cartController.clearCart);

module.exports = router;
