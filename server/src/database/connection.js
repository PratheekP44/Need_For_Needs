'use strict';

/**
 * Placeholder database bootstrap.
 * Mongoose connection will be wired in a later phase.
 * Do not connect or define schemas here.
 */
const mongoose = require('mongoose');
const logger = require('../config/logger');

async function connectDatabase(mongoUri) {
  if (!mongoUri) {
    logger.warn('MONGODB_URI not set — skipping database connection (architecture phase).');
    return null;
  }

  // Intentionally not connecting during architecture-only phase.
  // Call site may enable this in a later module.
  logger.info('Database module ready (mongoose loaded, connection deferred).');
  return mongoose;
}

module.exports = {
  mongoose,
  connectDatabase,
};
