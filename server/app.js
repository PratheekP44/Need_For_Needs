'use strict';

const path = require('path');
const express = require('express');
const { registerMiddleware } = require('./src/middlewares');
const { notFoundHandler, errorHandler } = require('./src/middlewares/errorHandler');
const routes = require('./src/routes');

/**
 * Builds and configures the Express application.
 */
function createApp(config) {
  const app = express();

  registerMiddleware(app, config);

  // Local product images (replaceable storage layer writes here in development).
  const uploadsRoot = path.join(process.cwd(), 'uploads');
  app.use('/uploads', express.static(uploadsRoot));

  app.use(routes);
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

module.exports = createApp;
