'use strict';

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
  app.use(routes);
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

module.exports = createApp;
