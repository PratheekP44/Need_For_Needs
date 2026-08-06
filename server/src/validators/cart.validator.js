'use strict';

const { body, param } = require('express-validator');

const addToCartValidator = [
  body('itemId').optional().trim().notEmpty(),
  body('item').optional().trim().notEmpty(),
  body('stockId').optional().trim().notEmpty(),
  body('lockerId').optional().trim(),
  body('boxId').optional().trim(),
  body('quantity').isInt({ min: 1 }).withMessage('quantity must be >= 1').toInt(),
  body().custom((_, { req }) => {
    const hasItem = Boolean(req.body.itemId || req.body.item);
    const hasStock = Boolean(req.body.stockId);
    if (!hasItem && !hasStock) {
      throw new Error('itemId (or legacy stockId) is required');
    }
    if (hasStock && !hasItem) {
      if (!req.body.lockerId || req.body.lockerId === 'null') {
        throw new Error('lockerId is required when using stockId');
      }
      if (!req.body.boxId || req.body.boxId === 'null') {
        throw new Error('boxId is required when using stockId');
      }
    }
    return true;
  }),
];

const updateCartValidator = [
  body('cartItemId').trim().notEmpty().withMessage('cartItemId is required'),
  body('quantity').isInt({ min: 1 }).withMessage('quantity must be >= 1').toInt(),
];

const removeCartItemValidator = [
  param('id').trim().notEmpty().withMessage('Cart item id is required'),
];

module.exports = {
  addToCartValidator,
  updateCartValidator,
  removeCartItemValidator,
};
