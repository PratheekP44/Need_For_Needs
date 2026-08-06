'use strict';

const { body, param, query } = require('express-validator');
const { BOX_STATUSES, BOX_DOOR_STATES } = require('../models/enums');

const listBoxesValidator = [
  query('page').optional().isInt({ min: 1 }).toInt(),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('limit must be an integer between 1 and 100')
    .toInt(),
  query('status').optional().isIn(BOX_STATUSES),
  query('doorState').optional().isIn(BOX_DOOR_STATES),
  query('isEmpty').optional().isIn(['true', 'false', '1', '0']),
  query('unassigned').optional().isIn(['true', 'false', '1', '0']),
  query('availableForStock').optional().isIn(['true', 'false', '1', '0']),
  query('locker').optional().isMongoId().withMessage('locker must be a valid ObjectId'),
  query('boxId').optional().isString(),
  query('search').optional().isString(),
  query('sort').optional().isString(),
];

const boxIdParamValidator = [
  param('id').trim().notEmpty().withMessage('Box id is required'),
];

const updateBoxValidator = [
  param('id').trim().notEmpty().withMessage('Box id is required'),
  body('status')
    .optional()
    .isIn(BOX_STATUSES)
    .withMessage(`status must be one of: ${BOX_STATUSES.join(', ')}`),
  body('doorState')
    .optional()
    .isIn(BOX_DOOR_STATES)
    .withMessage(`doorState must be one of: ${BOX_DOOR_STATES.join(', ')}`),
  body('isEmpty')
    .optional()
    .isBoolean()
    .withMessage('isEmpty must be a boolean')
    .toBoolean(),
  body('lastOpened')
    .optional({ nullable: true })
    .isISO8601()
    .withMessage('lastOpened must be a valid ISO date')
    .toDate(),
  body().custom((_, { req }) => {
    const allowed = ['status', 'doorState', 'isEmpty', 'lastOpened'];
    const keys = Object.keys(req.body || {});
    if (keys.length === 0) {
      throw new Error('At least one updatable field is required');
    }
    const invalid = keys.filter((key) => !allowed.includes(key));
    if (invalid.length > 0) {
      throw new Error(`Invalid fields: ${invalid.join(', ')}`);
    }
    return true;
  }),
];

module.exports = {
  listBoxesValidator,
  boxIdParamValidator,
  updateBoxValidator,
};
