'use strict';

const { body, param, query } = require('express-validator');
const { ITEM_CATEGORIES, ITEM_UNITS } = require('../models/enums');
const { assertPublicImageUrl } = require('../utils/imageUrl');

/**
 * imageUrl: optional on create/update.
 * - omitted / null / '' → allowed (empty means no image on create; on update
 *   empty means clear when the field is present in the body)
 * - absolute public http(s) URLs OK
 * - relative /uploads/... OK (legacy server uploads)
 * - localhost / private LAN / file:// rejected
 */
function optionalImageUrl() {
  return body('imageUrl')
    .optional({ values: 'null' })
    .customSanitizer((value) => {
      if (value === undefined || value === null) return value;
      if (typeof value !== 'string') return value;
      return value.trim();
    })
    .custom((value) => {
      assertPublicImageUrl(value, {
        allowEmpty: true,
        allowRelativeUploads: true,
      });
      return true;
    });
}

const createItemValidator = [
  body('itemId').trim().notEmpty().isLength({ min: 2, max: 50 }),
  body('name').trim().notEmpty().isLength({ min: 2, max: 150 }),
  body('description').trim().notEmpty().isLength({ max: 2000 }),
  body('category').isIn(ITEM_CATEGORIES),
  body('brand').trim().notEmpty().isLength({ max: 100 }),
  body('barcode').trim().notEmpty().isLength({ max: 64 }),
  optionalImageUrl(),
  body('sellingPrice').isFloat({ min: 0 }).toFloat(),
  body('costPrice').isFloat({ min: 0 }).toFloat(),
  body('gstPercentage').optional().isFloat({ min: 0, max: 100 }).toFloat(),
  body('unit').optional().isIn(ITEM_UNITS),
  body('isActive').optional().isBoolean().toBoolean(),
  body('tags').optional().isArray(),
  body('tags.*').optional().isString().isLength({ max: 40 }),
  body().custom((_, { req }) => {
    if (Number(req.body.sellingPrice) < Number(req.body.costPrice)) {
      throw new Error('Selling price must be greater than or equal to cost price');
    }
    return true;
  }),
];

const updateItemValidator = [
  param('id').trim().notEmpty(),
  body('itemId').optional().trim().isLength({ min: 2, max: 50 }),
  body('name').optional().trim().isLength({ min: 2, max: 150 }),
  body('description').optional().trim().isLength({ max: 2000 }),
  body('category').optional().isIn(ITEM_CATEGORIES),
  body('brand').optional().trim().isLength({ max: 100 }),
  body('barcode').optional().trim().isLength({ max: 64 }),
  optionalImageUrl(),
  body('sellingPrice').optional().isFloat({ min: 0 }).toFloat(),
  body('costPrice').optional().isFloat({ min: 0 }).toFloat(),
  body('gstPercentage').optional().isFloat({ min: 0, max: 100 }).toFloat(),
  body('unit').optional().isIn(ITEM_UNITS),
  body('isActive').optional().isBoolean().toBoolean(),
  body('tags').optional().isArray(),
];

const itemIdParamValidator = [param('id').trim().notEmpty()];

const listItemsValidator = [
  query('page').optional().isInt({ min: 1 }).toInt(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  query('category').optional().isIn(ITEM_CATEGORIES),
  query('brand').optional().isString(),
  query('barcode').optional().isString(),
  query('isActive').optional().isIn(['true', 'false', '1', '0']),
  query('minPrice').optional().isFloat({ min: 0 }).toFloat(),
  query('maxPrice').optional().isFloat({ min: 0 }).toFloat(),
  query('search').optional().isString(),
  query('sort').optional().isString(),
];

module.exports = {
  createItemValidator,
  updateItemValidator,
  itemIdParamValidator,
  listItemsValidator,
};
