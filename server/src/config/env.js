'use strict';

const path = require('path');
const dotenv = require('dotenv');

/**
 * Loads environment variables from `.env` (if present).
 * Safe to call multiple times.
 */
function loadEnv() {
  const envPath = path.resolve(process.cwd(), '.env');
  const result = dotenv.config({
    path: envPath,
    quiet: true,
  });

  if (result.error && result.error.code !== 'ENOENT') {
    throw result.error;
  }

  return {
    nodeEnv: process.env.NODE_ENV || 'development',
    port: Number(process.env.PORT) || 5000,
    mongoUri: process.env.MONGODB_URI || '',
    corsOrigin: process.env.CORS_ORIGIN || '*',
    rateLimitWindowMs: Number(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
    rateLimitMax: Number(process.env.RATE_LIMIT_MAX) || 100,
    logLevel: process.env.LOG_LEVEL || 'info',
  };
}

module.exports = {
  loadEnv,
};
