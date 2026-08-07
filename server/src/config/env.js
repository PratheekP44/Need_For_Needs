'use strict';

const path = require('path');
const dotenv = require('dotenv');

/**
 * Loads environment variables from the server `.env` file.
 * Path is resolved from this module (not process.cwd) so only ONE file is used.
 */
function loadEnv() {
  const envPath = path.resolve(__dirname, '../../.env');
  const result = dotenv.config({
    path: envPath,
    quiet: true,
    override: false, // never overwrite already-set process env
  });

  if (result.error && result.error.code !== 'ENOENT') {
    throw result.error;
  }

  const accessSecret = process.env.JWT_ACCESS_SECRET;
  const refreshSecret = process.env.JWT_REFRESH_SECRET;
  const unlockJwtSecret = process.env.UNLOCK_JWT_SECRET;
  const mongoUri = String(process.env.MONGODB_URI || '')
    .trim()
    .replace(/^['"]|['"]$/g, '');

  if (!accessSecret || !refreshSecret) {
    throw new Error(
      'JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must be set in the environment',
    );
  }

  if (!unlockJwtSecret) {
    throw new Error('UNLOCK_JWT_SECRET must be set in the environment');
  }

  if (!mongoUri) {
    throw new Error('MONGODB_URI must be set in the environment');
  }

  return {
    nodeEnv: process.env.NODE_ENV || 'development',
    port: Number(process.env.PORT) || 5000,
    mongoUri,
    envPath,
    corsOrigin: process.env.CORS_ORIGIN || '*',
    rateLimitWindowMs: Number(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
    rateLimitMax: Number(process.env.RATE_LIMIT_MAX) || 100,
    logLevel: process.env.LOG_LEVEL || 'info',
    jwtAccessSecret: accessSecret,
    jwtRefreshSecret: refreshSecret,
    /** Dedicated secret for Unlock JWTs — never reuse auth secrets. */
    unlockJwtSecret,
    /** Unlock JWT lifetime in seconds (default 10 minutes). */
    unlockJwtTtlSeconds: Number(process.env.UNLOCK_JWT_TTL_SECONDS) || 10 * 60,
    jwtAccessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
    jwtRefreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
    bcryptSaltRounds: Number(process.env.BCRYPT_SALT_ROUNDS) || 12,
    orderReservationMinutes: Number(process.env.ORDER_RESERVATION_MINUTES) || 15,
    razorpayKeyId: process.env.RAZORPAY_KEY_ID || '',
    razorpayKeySecret: process.env.RAZORPAY_KEY_SECRET || '',
  };
}

module.exports = {
  loadEnv,
};
