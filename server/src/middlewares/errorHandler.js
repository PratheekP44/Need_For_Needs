'use strict';

const logger = require('../config/logger');

function notFoundHandler(req, res) {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.originalUrl}`,
  });
}

function errorHandler(err, req, res, next) {
  let statusCode = err.statusCode || err.status || 500;
  let message = err.message || 'Internal Server Error';
  let details = err.details;

  if (err.name === 'ValidationError') {
    statusCode = 422;
    message = 'Validation failed';
    details = Object.values(err.errors || {}).map((entry) => ({
      field: entry.path,
      message: entry.message,
    }));
  }

  if (err.code === 11000) {
    statusCode = 409;
    const fields = Object.keys(err.keyPattern || err.keyValue || {});
    message = fields.length
      ? `Duplicate value for: ${fields.join(', ')}`
      : 'Duplicate key error';
  }

  if (err.name === 'JsonWebTokenError') {
    statusCode = 401;
    message = 'Invalid token';
  }

  if (err.name === 'TokenExpiredError') {
    statusCode = 401;
    message = 'Token expired';
  }

  if (err.name === 'CastError') {
    statusCode = 400;
    message = `Invalid ${err.path || 'identifier'}`;
  }

  logger.error(message, {
    statusCode,
    path: req.originalUrl,
    method: req.method,
    details,
    stack: process.env.NODE_ENV === 'production' ? undefined : err.stack,
  });

  res.status(statusCode).json({
    success: false,
    message,
    ...(details ? { details } : {}),
    ...(process.env.NODE_ENV === 'production' ? {} : { stack: err.stack }),
  });
}

module.exports = {
  notFoundHandler,
  errorHandler,
};
