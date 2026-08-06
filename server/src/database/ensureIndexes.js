'use strict';

const logger = require('../config/logger');

/**
 * Aligns Mongo indexes with current Payment schema.
 *
 * - Drops legacy / incompatible gatewayPaymentId uniques.
 * - Backfills `isMock` so the partial unique index (isMock:false) covers
 *   existing real SUCCESS rows and excludes historical mock captures.
 */
async function ensurePaymentIndexes() {
  const Payment = require('../models/Payment');
  const collection = Payment.collection;

  // Legacy sparse unique + any prior partial uniques that used unsupported
  // operators ($ne) or included mock rows (gateway:'razorpay' only).
  const dropNames = [
    'gatewayPaymentId_1',
    'gatewayPaymentId_success_real_unique',
  ];
  for (const name of dropNames) {
    try {
      await collection.dropIndex(name);
      logger.info(`Dropped Payment index: ${name}`);
    } catch (error) {
      const missing =
        error?.code === 27 ||
        error?.codeName === 'IndexNotFound' ||
        /index not found/i.test(String(error?.message || ''));
      if (!missing) {
        logger.warn(`Could not drop Payment index ${name}: ${error.message}`);
      }
    }
  }

  // Backfill isMock before recreating the partial unique index.
  const mockBackfill = await Payment.updateMany(
    {
      $or: [
        { paymentMethod: 'mock' },
        { gatewayPaymentId: { $regex: /^pay_mock_/i } },
        { gatewayOrderId: { $regex: /^order_mock_/i } },
      ],
    },
    { $set: { isMock: true } },
  );
  const realBackfill = await Payment.updateMany(
    {
      $or: [{ isMock: { $exists: false } }, { isMock: null }],
    },
    { $set: { isMock: false } },
  );
  logger.info('Payment isMock backfill', {
    markedMock: mockBackfill.modifiedCount,
    markedReal: realBackfill.modifiedCount,
  });

  await Payment.syncIndexes();
  logger.info('Payment indexes synchronized');
}

module.exports = {
  ensurePaymentIndexes,
};
