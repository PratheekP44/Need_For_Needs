'use strict';

const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const cookieParser = require('cookie-parser');
const rateLimit = require('express-rate-limit');
const express = require('express');
const logger = require('../config/logger');

/**
 * True for Flutter Web / local browser origins on any port.
 * `localhost` and `127.0.0.1` are different browser origins.
 */
function isLocalDevOrigin(origin) {
  if (!origin) return false;
  try {
    const url = new URL(origin);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return false;
    return (
      url.hostname === 'localhost' ||
      url.hostname === '127.0.0.1' ||
      url.hostname === '::1'
    );
  } catch (_) {
    return false;
  }
}

function resolveCorsOrigin(config) {
  const configured = String(config.corsOrigin || '*')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);

  return (origin, callback) => {
    // Non-browser clients (curl, Postman, server-to-server) send no Origin.
    if (!origin) {
      callback(null, true);
      return;
    }

    if (configured.includes('*')) {
      callback(null, true);
      return;
    }

    if (configured.includes(origin)) {
      callback(null, true);
      return;
    }

    // Flutter Web picks a random localhost port each run — allow any local port
    // outside production without editing CORS_ORIGIN every time.
    if (config.nodeEnv !== 'production' && isLocalDevOrigin(origin)) {
      callback(null, true);
      return;
    }

    logger.warn(`CORS blocked origin: ${origin}`);
    callback(null, false);
  };
}

/**
 * Registers cross-cutting Express middleware.
 */
function registerMiddleware(app, config) {
  app.set('trust proxy', 1);

  // APIs must allow cross-origin reads from Flutter Web. Helmet's default
  // Cross-Origin-Resource-Policy: same-origin causes browser "Failed to fetch".
  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );
  app.use(
    cors({
      origin: resolveCorsOrigin(config),
      credentials: true,
      methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Accept', 'Authorization'],
      optionsSuccessStatus: 204,
    }),
  );
  app.use(compression());
  app.use(cookieParser());
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true }));

  const morganFormat = config.nodeEnv === 'production' ? 'combined' : 'dev';
  app.use(morgan(morganFormat, { stream: logger.stream }));

  app.use(
    rateLimit({
      windowMs: config.rateLimitWindowMs,
      max: config.rateLimitMax,
      standardHeaders: true,
      legacyHeaders: false,
      message: {
        success: false,
        message: 'Too many requests, please try again later.',
      },
    }),
  );
}

module.exports = {
  registerMiddleware,
  ...require('./auth.middleware'),
  validate: require('./validate'),
  asyncHandler: require('./asyncHandler'),
};
