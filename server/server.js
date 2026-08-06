'use strict';

const path = require('path');
const createApp = require('./app');
const { loadEnv } = require('./src/config/env');
const logger = require('./src/config/logger');
const {
  connectDatabase,
  disconnectDatabase,
  maskMongoUri,
} = require('./src/database/connection');
const { startOrderExpiryJob } = require('./src/jobs/orderExpiry.job');

async function bootstrap() {
  // 1) Load dotenv + validate env
  const config = loadEnv();
  logger.info(`Loaded env file: ${config.envPath}`);
  logger.info(`MONGODB_URI: ${maskMongoUri(config.mongoUri)}`);

  // 2) Database connection (uses exact sanitized MONGODB_URI)
  await connectDatabase(config.mongoUri);

  // 2b) Align payment indexes (drop legacy unique gatewayPaymentId)
  const { ensurePaymentIndexes } = require('./src/database/ensureIndexes');
  await ensurePaymentIndexes();

  // 3) Express app
  const app = createApp(config);

  // 4) Background jobs
  const stopExpiryJob = startOrderExpiryJob();

  // 5) Listen on all interfaces so Flutter Web / emulators can reach the API
  const host = '0.0.0.0';
  const server = app.listen(config.port, host, () => {
    logger.info(`Campus Essentials API listening on http://${host}:${config.port}`);
    logger.info(`Environment: ${config.nodeEnv}`);
    logger.info(`CORS_ORIGIN config: ${config.corsOrigin}`);
    logger.info(`Working directory: ${process.cwd()}`);
    logger.info(`Entrypoint: ${path.resolve(__filename)}`);
  });

  const shutdown = async (signal) => {
    logger.info(`${signal} received - shutting down gracefully`);
    if (typeof stopExpiryJob === 'function') {
      stopExpiryJob();
    }
    server.close(async () => {
      try {
        await disconnectDatabase();
      } catch (error) {
        logger.error('Error during database disconnect', {
          message: error.message,
        });
      }
      logger.info('HTTP server closed');
      process.exit(0);
    });
  };

  process.on('SIGTERM', () => {
    shutdown('SIGTERM');
  });
  process.on('SIGINT', () => {
    shutdown('SIGINT');
  });

  process.on('unhandledRejection', (reason) => {
    logger.error('Unhandled Rejection', { reason: String(reason) });
  });

  process.on('uncaughtException', (error) => {
    logger.error('Uncaught Exception', {
      message: error.message,
      stack: error.stack,
    });
    process.exit(1);
  });

  return server;
}

bootstrap().catch((error) => {
  logger.error('Failed to start server', {
    message: error.message,
    stack: error.stack,
  });
  process.exit(1);
});
