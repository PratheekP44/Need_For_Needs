'use strict';

const { body, param, query } = require('express-validator');
const { LOCKER_STATUSES } = require('../models/enums');

const objectIdOptional = body('BLEDevice')
  .optional({ nullable: true })
  .custom((value) => value === null || /^[a-fA-F0-9]{24}$/.test(String(value)))
  .withMessage('BLEDevice must be a valid ObjectId or null');

const createLockerValidator = [
  body('lockerId')
    .trim()
    .notEmpty()
    .withMessage('lockerId is required')
    .isLength({ min: 2, max: 50 })
    .withMessage('lockerId must be between 2 and 50 characters'),
  body('lockerName')
    .trim()
    .notEmpty()
    .withMessage('lockerName is required')
    .isLength({ min: 2, max: 120 })
    .withMessage('lockerName must be between 2 and 120 characters'),
  body('latitude')
    .notEmpty()
    .withMessage('latitude is required')
    .isFloat({ min: -90, max: 90 })
    .withMessage('latitude must be between -90 and 90')
    .toFloat(),
  body('longitude')
    .notEmpty()
    .withMessage('longitude is required')
    .isFloat({ min: -180, max: 180 })
    .withMessage('longitude must be between -180 and 180')
    .toFloat(),
  body('totalBoxes')
    .notEmpty()
    .withMessage('totalBoxes is required')
    .isInt({ min: 1, max: 500 })
    .withMessage('totalBoxes must be an integer between 1 and 500')
    .toInt(),
  body('status')
    .optional()
    .isIn(LOCKER_STATUSES)
    .withMessage(`status must be one of: ${LOCKER_STATUSES.join(', ')}`),
  body('description')
    .optional()
    .isString()
    .isLength({ max: 1000 })
    .withMessage('description cannot exceed 1000 characters'),
  objectIdOptional,
];

const updateLockerValidator = [
  param('id').trim().notEmpty().withMessage('Locker id is required'),
  body('lockerId')
    .optional()
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('lockerId must be between 2 and 50 characters'),
  body('lockerName')
    .optional()
    .trim()
    .isLength({ min: 2, max: 120 })
    .withMessage('lockerName must be between 2 and 120 characters'),
  body('latitude')
    .optional()
    .isFloat({ min: -90, max: 90 })
    .withMessage('latitude must be between -90 and 90')
    .toFloat(),
  body('longitude')
    .optional()
    .isFloat({ min: -180, max: 180 })
    .withMessage('longitude must be between -180 and 180')
    .toFloat(),
  body('totalBoxes')
    .optional()
    .isInt({ min: 1, max: 500 })
    .withMessage('totalBoxes must be an integer between 1 and 500')
    .toInt(),
  body('status')
    .optional()
    .isIn(LOCKER_STATUSES)
    .withMessage(`status must be one of: ${LOCKER_STATUSES.join(', ')}`),
  body('description')
    .optional()
    .isString()
    .isLength({ max: 1000 })
    .withMessage('description cannot exceed 1000 characters'),
  objectIdOptional,
];

const lockerIdParamValidator = [
  param('id').trim().notEmpty().withMessage('Locker id is required'),
];

const listLockersValidator = [
  query('page').optional().isInt({ min: 1 }).toInt(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  query('status').optional().isIn(LOCKER_STATUSES),
  query('search').optional().isString(),
  query('sort').optional().isString(),
  query('lockerId').optional().isString(),
];

module.exports = {
  createLockerValidator,
  updateLockerValidator,
  lockerIdParamValidator,
  listLockersValidator,
};
