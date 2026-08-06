'use strict';

const orderService = require('../services/order.service');
const logger = require('../config/logger');

const DEFAULT_INTERVAL_MS = 60 * 1000;

/**
 * Periodically releases stock for unpaid expired orders.
 */
function startOrderExpiryJob(intervalMs = DEFAULT_INTERVAL_MS) {
  const tick = async () => {
    try {
      const count = await orderService.expireDueOrders();
      if (count > 0) {
        logger.info(`Expired ${count} unpaid order(s) and released reserved stock`);
      }
    } catch (error) {
      logger.error('Order expiry job failed', { message: error.message });
    }
  };

  // Run once shortly after boot, then on interval.
  const initial = setTimeout(tick, 5 * 1000);
  const timer = setInterval(tick, intervalMs);

  if (typeof timer.unref === 'function') timer.unref();
  if (typeof initial.unref === 'function') initial.unref();

  return () => {
    clearTimeout(initial);
    clearInterval(timer);
  };
}

module.exports = {
  startOrderExpiryJob,
};
