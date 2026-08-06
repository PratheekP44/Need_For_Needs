'use strict';

const { validationResult } = require('express-validator');
const AppError = require('../utils/AppError');
const logger = require('../config/logger');

/**
 * Runs after express-validator chains and rejects invalid requests.
 */
function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const details = errors.array().map((error) => ({
      field: error.path,
      message: error.msg,
      value: error.value,
      location: error.location,
    }));

    logger.warn('Validation failed', {
      method: req.method,
      path: req.originalUrl,
      query: req.query,
      body: req.body,
      details,
    });

    // Temporary explicit console dump for Flutter integration debugging.
    // eslint-disable-next-line no-console
    console.error('[VALIDATION] query=', JSON.stringify(req.query, null, 2));
    // eslint-disable-next-line no-console
    console.error('[VALIDATION] body=', JSON.stringify(req.body, null, 2));
    // eslint-disable-next-line no-console
    console.error('[VALIDATION] errors=', JSON.stringify(details, null, 2));

    return next(new AppError('Validation failed', 422, details));
  }
  return next();
}

module.exports = validate;
