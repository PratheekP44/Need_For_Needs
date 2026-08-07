'use strict';

const dns = require('dns');
const mongoose = require('mongoose');
const logger = require('../config/logger');

/**
 * Masks credentials in a MongoDB URI for safe logging.
 */
function maskMongoUri(uri) {
  return String(uri).replace(/\/\/([^:/@]+):([^@]+)@/, '//$1:***@');
}

/**
 * Trims whitespace / wrapping quotes that sometimes appear in .env values.
 */
function sanitizeMongoUri(uri) {
  return String(uri || '')
    .trim()
    .replace(/^['"]|['"]$/g, '');
}

/**
 * Node on some Windows setups uses 127.0.0.1 as the only DNS server.
 * That local resolver often returns ECONNREFUSED for SRV queries used by
 * mongodb+srv://, while Compass/system DNS still work.
 */
function ensurePublicDnsForSrv(uri) {
  if (!uri.startsWith('mongodb+srv://')) {
    return false;
  }

  const servers = dns.getServers();
  const onlyLoopback = servers.every(
    (server) => server === '127.0.0.1' || server === '::1',
  );

  if (onlyLoopback) {
    dns.setServers(['8.8.8.8', '1.1.1.1']);
    logger.info(
      'MongoDB SRV DNS: local resolver refused SRV lookups; switched to 8.8.8.8 / 1.1.1.1',
    );
    return true;
  }

  return false;
}

async function connectWithUri(uri) {
  await mongoose.connect(uri, {
    serverSelectionTimeoutMS: 20000,
  });
}

async function connectDatabase(mongoUri) {
  const uri = sanitizeMongoUri(mongoUri);

  if (!uri) {
    throw new Error('MONGODB_URI is required to start the server');
  }

  if (!uri.startsWith('mongodb://') && !uri.startsWith('mongodb+srv://')) {
    throw new Error(
      'MONGODB_URI must start with mongodb:// or mongodb+srv://',
    );
  }

  mongoose.set('strictQuery', true);

  logger.info(`Connecting to MongoDB: ${maskMongoUri(uri)}`);
  ensurePublicDnsForSrv(uri);

  try {
    await connectWithUri(uri);
  } catch (error) {
    const isSrvRefused =
      uri.startsWith('mongodb+srv://') &&
      /querySrv ECONNREFUSED/i.test(String(error.message || error));

    if (!isSrvRefused) {
      throw error;
    }

    // Retry once with public DNS if the first attempt still failed on SRV.
    dns.setServers(['8.8.8.8', '1.1.1.1']);
    logger.warn(
      'MongoDB SRV lookup failed (querySrv ECONNREFUSED). Retrying with public DNS resolvers.',
    );
    await connectWithUri(uri);
  }

  logger.info(
    `MongoDB connected successfully (${mongoose.connection.host}/${mongoose.connection.name})`,
  );

  // Register all schemas (incl. BLEDevice) so populate refs never hit
  // MissingSchemaError for pluralized names like "BLEDevices".
  require('../models');
  logger.info(`Mongoose models registered: ${mongoose.modelNames().join(', ')}`);

  return mongoose.connection;
}

async function disconnectDatabase() {
  if (mongoose.connection.readyState !== 0) {
    await mongoose.disconnect();
    logger.info('MongoDB disconnected');
  }
}

module.exports = {
  mongoose,
  connectDatabase,
  disconnectDatabase,
  maskMongoUri,
  sanitizeMongoUri,
};
