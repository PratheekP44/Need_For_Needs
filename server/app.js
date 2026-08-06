'use strict';

const express = require('express');
const { registerMiddleware } = require('./src/middlewares');
const { notFoundHandler, errorHandler } = require('./src/middlewares/errorHandler');
const routes = require('./src/routes');
const { getStorage, resolveUploadsRoot } = require('./src/storage/storage');
const logger = require('./src/config/logger');

/**
 * Builds and configures the Express application.
 */
function createApp(config) {
  const app = express();

  registerMiddleware(app, config);

  // Product images — same root as LocalFileStorage (UPLOADS_DIR or server/uploads).
  const uploadsRoot = resolveUploadsRoot();
  getStorage().ensureReady().catch((err) => {
    logger.error('Failed to prepare uploads directory', { message: err.message });
  });
  logger.info(`Static /uploads → ${uploadsRoot}`);
  app.use(
    '/uploads',
    express.static(uploadsRoot, {
      fallthrough: true,
      index: false,
      maxAge: config.nodeEnv === 'production' ? '7d' : 0,
      etag: true,
    }),
  );

  app.use(routes);
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

module.exports = createApp;
