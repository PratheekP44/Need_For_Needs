'use strict';

const express = require('express');
const stockController = require('../controllers/stock.controller');
const {
  createStockValidator,
  createStockBatchValidator,
  updateStockValidator,
  restockValidator,
  moveStockValidator,
  stockIdParamValidator,
  listStockValidator,
} = require('../validators/stock.validator');
const validate = require('../middlewares/validate');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(authenticate);

router.get(
  '/',
  authorize('user', 'admin'),
  listStockValidator,
  validate,
  stockController.listStock,
);

router.post(
  '/',
  authorize('admin'),
  createStockValidator,
  validate,
  stockController.createStock,
);

router.post(
  '/batch',
  authorize('admin'),
  createStockBatchValidator,
  validate,
  stockController.createStockBatch,
);

router.post(
  '/:id/restock',
  authorize('admin'),
  restockValidator,
  validate,
  stockController.restock,
);

router.post(
  '/:id/move',
  authorize('admin'),
  moveStockValidator,
  validate,
  stockController.moveStock,
);

router.get(
  '/:id',
  authorize('user', 'admin'),
  stockIdParamValidator,
  validate,
  stockController.getStock,
);

router.put(
  '/:id',
  authorize('admin'),
  updateStockValidator,
  validate,
  stockController.updateStock,
);

router.delete(
  '/:id',
  authorize('admin'),
  stockIdParamValidator,
  validate,
  stockController.deleteStock,
);

module.exports = router;
