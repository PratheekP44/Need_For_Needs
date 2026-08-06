'use strict';

const express = require('express');
const authController = require('../controllers/auth.controller');
const {
  signupValidator,
  loginValidator,
  refreshValidator,
  logoutValidator,
  resetAdminPasswordValidator,
} = require('../validators/auth.validator');
const validate = require('../middlewares/validate');
const { authenticate } = require('../middlewares/auth.middleware');
const { loadEnv } = require('../config/env');
const AppError = require('../utils/AppError');

const router = express.Router();

function developmentOnly(req, res, next) {
  const { nodeEnv } = loadEnv();
  if (nodeEnv === 'production') {
    return next(new AppError('Not available in production', 404));
  }
  return next();
}

router.post('/signup', signupValidator, validate, authController.signup);
router.post('/login', loginValidator, validate, authController.login);
router.post('/logout', authenticate, logoutValidator, validate, authController.logout);
router.post('/refresh', refreshValidator, validate, authController.refresh);
router.get('/profile', authenticate, authController.profile);

// Development forgot-password / admin reset (no email OTP).
router.post(
  '/dev/reset-admin-password',
  developmentOnly,
  resetAdminPasswordValidator,
  validate,
  authController.resetAdminPassword,
);

module.exports = router;
