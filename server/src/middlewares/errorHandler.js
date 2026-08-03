'use strict';

const logger = require('../config/logger');

/**
 * 404 handler for unmatched routes.
 */
function notFoundHandler(req, res, next) {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.originalUrl}`,
  });
}

/**
 * Global Express error handler.
 * Must be registered after all routes.
 */
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  const statusCode = err.statusCode || err.status || 500;
  const message = err.message || 'Internal Server Error';

  logger.error(message, {
    statusCode,
    path: req.originalUrl,
    method: req.method,
    stack: process.env.NODE_ENV === 'production' ? undefined : err.stack,
  });

  res.status(statusCode).json({
    success: false,
    message,
    ...(process.env.NODE_ENV === 'production'
      ? {}
      : { stack: err.stack }),
  });
}

module.exports = {
  notFoundHandler,
  errorHandler,
};
