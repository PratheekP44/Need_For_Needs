'use strict';

const Order = require('../models/Order');
const User = require('../models/User');
const Admin = require('../models/Admin');
const Item = require('../models/Item');
const Stock = require('../models/Stock');
const Box = require('../models/Box');
const Locker = require('../models/Locker');
const crypto = require('crypto');

function startOfUtcDay(date = new Date()) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

class AdminService {
  async getDashboardStats() {
    const todayStart = startOfUtcDay();

    const [
      totalUsers,
      totalAdmins,
      totalLockers,
      lockersOnline,
      lockersOffline,
      totalItems,
      totalStockRecords,
      lowStock,
      outOfStock,
      emptyBoxes,
      occupiedBoxes,
      availableBoxes,
      ordersToday,
      revenueAgg,
      totalOrders,
      revenueAll,
    ] = await Promise.all([
      User.countDocuments({ status: 'active' }),
      Admin.countDocuments({ status: 'active' }),
      Locker.countDocuments(),
      Locker.countDocuments({ status: 'ACTIVE' }),
      Locker.countDocuments({ status: { $in: ['OFFLINE', 'DISABLED', 'MAINTENANCE'] } }),
      Item.countDocuments({ isActive: true }),
      Stock.countDocuments(),
      Stock.countDocuments({ status: 'LOW_STOCK' }),
      Stock.countDocuments({ status: 'OUT_OF_STOCK' }),
      Box.countDocuments({ isEmpty: true, status: 'EMPTY' }),
      Box.countDocuments({ isEmpty: false }),
      Box.countDocuments({ status: 'AVAILABLE' }),
      Order.countDocuments({
        createdAt: { $gte: todayStart },
        status: { $nin: ['CANCELLED', 'EXPIRED'] },
      }),
      Order.aggregate([
        {
          $match: {
            createdAt: { $gte: todayStart },
            paymentStatus: 'SUCCESS',
          },
        },
        { $group: { _id: null, total: { $sum: '$grandTotal' } } },
      ]),
      Order.countDocuments({ status: { $nin: ['CANCELLED', 'EXPIRED'] } }),
      Order.aggregate([
        { $match: { paymentStatus: 'SUCCESS' } },
        { $group: { _id: null, total: { $sum: '$grandTotal' } } },
      ]),
    ]);

    const revenueToday = revenueAgg[0]?.total || 0;
    const totalRevenue = revenueAll[0]?.total || 0;

    let inventoryStatus = 'Healthy stock levels';
    if (outOfStock > 0 || lowStock > 0) {
      inventoryStatus = `${lowStock + outOfStock} item(s) need restock soon`;
    }

    return {
      totalUsers,
      totalAdmins,
      totalLockers,
      availableLockers: lockersOnline,
      lockersOnline,
      lockersOffline,
      totalItems,
      totalStockRecords,
      lowStockCount: lowStock,
      outOfStockCount: outOfStock,
      emptyBoxes,
      occupiedBoxes,
      availableBoxes,
      ordersToday,
      revenueToday,
      totalOrders,
      totalRevenue,
      inventoryStatus,
    };
  }
}

module.exports = new AdminService();
module.exports.startOfUtcDay = startOfUtcDay;

/**
 * Issues a BLE-compatible collection token after successful payment.
 *
 * Format: CE1.<orderId>.<lockerId>.<boxId>.<expiresAtUnix>.<nonce>
 */
function issueCollectionToken({
  orderNumber,
  lockerId,
  boxId,
  ttlSeconds = 24 * 60 * 60,
} = {}) {
  const orderId = String(orderNumber || '').toUpperCase();
  const locker = String(lockerId || 'LOCKER').trim() || 'LOCKER';
  const box = String(boxId || 'BOX').trim() || 'BOX';
  const expiresAtUnix = Math.floor(Date.now() / 1000) + Math.max(60, ttlSeconds);
  const nonce = crypto.randomBytes(4).toString('hex');
  return `CE1.${orderId}.${locker}.${box}.${expiresAtUnix}.${nonce}`;
}

module.exports.issueCollectionToken = issueCollectionToken;
