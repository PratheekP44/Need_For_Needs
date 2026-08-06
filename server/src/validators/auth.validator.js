'use strict';

const { body } = require('express-validator');
const { AUTH_ACCOUNT_TYPES } = require('../models/enums');

const passwordRules = body('password')
  .isString()
  .withMessage('Password is required')
  .isLength({ min: 8, max: 128 })
  .withMessage('Password must be between 8 and 128 characters')
  .matches(/[A-Za-z]/)
  .withMessage('Password must contain at least one letter')
  .matches(/[0-9]/)
  .withMessage('Password must contain at least one number');

const signupValidator = [
  body('name')
    .trim()
    .notEmpty()
    .withMessage('Name is required')
    .isLength({ min: 2, max: 100 })
    .withMessage('Name must be between 2 and 100 characters'),
  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email is required')
    .isEmail()
    .withMessage('Please provide a valid email address')
    .normalizeEmail(),
  body('phone')
    .trim()
    .notEmpty()
    .withMessage('Phone is required')
    // Accept common UI formatting (spaces, dashes, parentheses), then validate digits.
    .customSanitizer((value) => {
      if (typeof value !== 'string') return value;
      const trimmed = value.trim();
      const hasPlus = trimmed.startsWith('+');
      const digits = trimmed.replace(/\D/g, '');
      return hasPlus ? `+${digits}` : digits;
    })
    .matches(/^\+?[0-9]{7,15}$/)
    .withMessage('Please provide a valid phone number (7-15 digits)'),
  passwordRules,
  body('accountType')
    .optional()
    .isIn(AUTH_ACCOUNT_TYPES)
    .withMessage(`accountType must be one of: ${AUTH_ACCOUNT_TYPES.join(', ')}`),
];

const loginValidator = [
  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email is required')
    .isEmail()
    .withMessage('Please provide a valid email address')
    .normalizeEmail(),
  body('password')
    .notEmpty()
    .withMessage('Password is required'),
];

const refreshValidator = [
  body('refreshToken')
    .optional()
    .isString()
    .withMessage('refreshToken must be a string'),
];

const logoutValidator = [
  body('refreshToken')
    .optional()
    .isString()
    .withMessage('refreshToken must be a string'),
];

const resetAdminPasswordValidator = [
  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email is required')
    .isEmail()
    .withMessage('Please provide a valid email address')
    .normalizeEmail(),
  body('newPassword')
    .isString()
    .withMessage('newPassword is required')
    .isLength({ min: 8, max: 128 })
    .withMessage('Password must be between 8 and 128 characters')
    .matches(/[A-Za-z]/)
    .withMessage('Password must contain at least one letter')
    .matches(/[0-9]/)
    .withMessage('Password must contain at least one number'),
];

module.exports = {
  signupValidator,
  loginValidator,
  refreshValidator,
  logoutValidator,
  resetAdminPasswordValidator,
};
