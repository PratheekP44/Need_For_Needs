'use strict';

const express = require('express');
const itemController = require('../controllers/item.controller');
const {
  createItemValidator,
  updateItemValidator,
  itemIdParamValidator,
  listItemsValidator,
} = require('../validators/item.validator');
const validate = require('../middlewares/validate');
const { authenticate, authorize } = require('../middlewares/auth.middleware');
const {
  uploadItemImage,
  handleMulterError,
} = require('../middlewares/upload.middleware');

const router = express.Router();

router.use(authenticate);

router.get(
  '/',
  authorize('user', 'admin'),
  listItemsValidator,
  validate,
  itemController.listItems,
);

router.get(
  '/:id',
  authorize('user', 'admin'),
  itemIdParamValidator,
  validate,
  itemController.getItem,
);

router.post(
  '/',
  authorize('admin'),
  createItemValidator,
  validate,
  itemController.createItem,
);

router.put(
  '/:id',
  authorize('admin'),
  updateItemValidator,
  validate,
  itemController.updateItem,
);

router.post(
  '/:id/image',
  authorize('admin'),
  uploadItemImage,
  handleMulterError,
  itemIdParamValidator,
  validate,
  itemController.uploadItemImage,
);

router.delete(
  '/:id/image',
  authorize('admin'),
  itemIdParamValidator,
  validate,
  itemController.removeItemImage,
);

router.delete(
  '/:id',
  authorize('admin'),
  itemIdParamValidator,
  validate,
  itemController.deleteItem,
);

module.exports = router;
