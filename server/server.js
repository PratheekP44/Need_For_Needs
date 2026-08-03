'use strict';

const createApp = require('./app');
const { loadEnv } = require('./src/config/env');
const logger = require('./src/config/logger');
const { connectDatabase } = require('./src/database/connection');

async function bootstrap() {
  const config = loadEnv();
  const app = createApp(config);

  // Architecture phase: prepare DB module without requiring a live MongoDB.
  await connectDatabase(config.mongoUri);

  const server = app.listen(config.port, () => {
    logger.info(`Campus Essentials API listening on port ${config.port}`);
    logger.info(`Environment: ${config.nodeEnv}`);
  });

  const shutdown = (signal) => {
    logger.info(`${signal} received — shutting down gracefully`);
    server.close(() => {
      logger.info('HTTP server closed');
      process.exit(0);
    });
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));

  process.on('unhandledRejection', (reason) => {
    logger.error('Unhandled Rejection', { reason: String(reason) });
  });

  process.on('uncaughtException', (error) => {
    logger.error('Uncaught Exception', { message: error.message, stack: error.stack });
    process.exit(1);
  });

  return server;
}

bootstrap().catch((error) => {
  logger.error('Failed to start server', { message: error.message, stack: error.stack });
  process.exit(1);
});
