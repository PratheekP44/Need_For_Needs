'use strict';

const { body, param, query } = require('express-validator');
const { STOCK_STATUSES, ITEM_CATEGORIES } = require('../models/enums');

const createStockValidator = [
  body('stockId').optional().trim().isLength({ min: 2, max: 50 }),
  body('box').trim().notEmpty().withMessage('box is required'),
  body('item').trim().notEmpty().withMessage('item is required'),
  body('locker').optional().isString(),
  // Unit-box model: one physical item per box (qty always 1).
  body('currentQuantity').optional().isInt({ min: 0, max: 1 }).toInt(),
  body('maximumQuantity').optional().isInt({ min: 1, max: 1 }).toInt(),
  body('reorderLevel').optional().isInt({ min: 0 }).toInt(),
  body('expiryDate').optional({ nullable: true }).isISO8601().toDate(),
  body('batchNumber').optional().isString().isLength({ max: 64 }),
  body('supplierName').optional().isString().isLength({ max: 120 }),
  body('purchaseDate').optional({ nullable: true }).isISO8601().toDate(),
  body('status').optional().isIn(STOCK_STATUSES),
];

const createStockBatchValidator = [
  body('item').trim().notEmpty().withMessage('item is required'),
  body('quantity').isInt({ min: 1, max: 100 }).toInt(),
  body('boxes')
    .isArray({ min: 1 })
    .withMessage('Invalid box selection: boxes must be a non-empty array'),
  body('boxes.*').trim().notEmpty().withMessage('Invalid box selection'),
  body('reorderLevel').optional().isInt({ min: 0 }).toInt(),
  body('expiryDate').optional({ nullable: true }).isISO8601().toDate(),
  body('batchNumber').optional().isString().isLength({ max: 64 }),
  body('supplierName').optional().isString().isLength({ max: 120 }),
  body('purchaseDate').optional({ nullable: true }).isISO8601().toDate(),
  body().custom((_, { req }) => {
    const boxes = req.body.boxes || [];
    const quantity = Number(req.body.quantity);
    if (boxes.length !== quantity) {
      throw new Error(
        `Invalid box selection: select exactly ${quantity} empty box(es); got ${boxes.length}`,
      );
    }
    const unique = new Set(boxes.map((b) => String(b)));
    if (unique.size !== boxes.length) {
      throw new Error('Invalid box selection: duplicate boxes are not allowed');
    }
    return true;
  }),
];

const updateStockValidator = [
  param('id').trim().notEmpty(),
  body('stockId').optional().trim().isLength({ min: 2, max: 50 }),
  body('currentQuantity').optional().isInt({ min: 0 }).toInt(),
  body('maximumQuantity').optional().isInt({ min: 1 }).toInt(),
  body('reorderLevel').optional().isInt({ min: 0 }).toInt(),
  body('expiryDate').optional({ nullable: true }).isISO8601().toDate(),
  body('batchNumber').optional().isString().isLength({ max: 64 }),
  body('supplierName').optional().isString().isLength({ max: 120 }),
  body('purchaseDate').optional({ nullable: true }).isISO8601().toDate(),
  body('status').optional().isIn(STOCK_STATUSES),
];

const restockValidator = [
  param('id').trim().notEmpty(),
  body('addQuantity').optional().isInt({ min: 1 }).toInt(),
  body('setQuantity').optional().isInt({ min: 0 }).toInt(),
  body('batchNumber').optional().isString().isLength({ max: 64 }),
  body('supplierName').optional().isString().isLength({ max: 120 }),
  body('expiryDate').optional({ nullable: true }).isISO8601().toDate(),
  body('purchaseDate').optional({ nullable: true }).isISO8601().toDate(),
  body().custom((_, { req }) => {
    if (req.body.addQuantity === undefined && req.body.setQuantity === undefined) {
      throw new Error('Provide addQuantity or setQuantity');
    }
    return true;
  }),
];

const moveStockValidator = [
  param('id').trim().notEmpty(),
  body('toBox')
    .optional()
    .isString(),
  body('box').optional().isString(),
  body().custom((_, { req }) => {
    if (!req.body.toBox && !req.body.box) {
      throw new Error('Provide toBox (target box id)');
    }
    return true;
  }),
];

const stockIdParamValidator = [param('id').trim().notEmpty()];

const listStockValidator = [
  query('page').optional().isInt({ min: 1 }).toInt(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  query('status').optional().isIn(STOCK_STATUSES),
  query('locker').optional().isMongoId(),
  query('box').optional().isMongoId(),
  query('item').optional().isMongoId(),
  query('availability').optional().isIn(['available', 'unavailable']),
  query('category').optional().isIn(ITEM_CATEGORIES),
  query('brand').optional().isString(),
  query('barcode').optional().isString(),
  query('search').optional().isString(),
  query('searchItem').optional().isString(),
  query('minPrice').optional().isFloat({ min: 0 }).toFloat(),
  query('maxPrice').optional().isFloat({ min: 0 }).toFloat(),
  query('sort').optional().isString(),
];

module.exports = {
  createStockValidator,
  createStockBatchValidator,
  updateStockValidator,
  restockValidator,
  moveStockValidator,
  stockIdParamValidator,
  listStockValidator,
};
