'use strict';

const Order = require('../models/Order');

class OrderRepository {
  async create(data) {
    return Order.create(data);
  }

  async findById(id) {
    return Order.findById(id)
      .populate('locker', 'lockerId lockerName status')
      .populate('items.item')
      .populate('items.stock')
      .populate('items.box', 'boxId boxNumber status')
      .populate('items.locker', 'lockerId lockerName status')
      .exec();
  }

  async findByOrderNumber(orderNumber) {
    return Order.findOne({ orderNumber: String(orderNumber).toUpperCase() })
      .populate('locker', 'lockerId lockerName status')
      .populate('items.item')
      .populate('items.stock')
      .populate('items.box', 'boxId boxNumber status')
      .populate('items.locker', 'lockerId lockerName status')
      .exec();
  }

  async findByIdOrOrderNumber(idOrNumber) {
    if (/^[a-fA-F0-9]{24}$/.test(String(idOrNumber))) {
      const byId = await this.findById(idOrNumber);
      if (byId) return byId;
    }
    return this.findByOrderNumber(idOrNumber);
  }

  /**
   * Order load for unlock-payload: includes locker BLE device + box numbers.
   */
  async findByIdOrOrderNumberForUnlock(idOrNumber) {
    const populateUnlock = (query) =>
      query
        .populate({
          path: 'locker',
          select: 'lockerId lockerName status terminalNumber BLEDevice',
          populate: {
            path: 'BLEDevice',
            select: 'macAddress deviceName advertisementId status firmwareVersion',
          },
        })
        .populate('items.item', 'itemId name')
        .populate('items.stock', 'stockId')
        .populate('items.box', 'boxId boxNumber status')
        .populate('items.locker', 'lockerId lockerName status');

    if (/^[a-fA-F0-9]{24}$/.test(String(idOrNumber))) {
      const byId = await populateUnlock(Order.findById(idOrNumber)).exec();
      if (byId) return byId;
    }
    return populateUnlock(
      Order.findOne({ orderNumber: String(idOrNumber).toUpperCase() }),
    ).exec();
  }

  async list({ filter, sort, skip, limit }) {
    const [items, total] = await Promise.all([
      Order.find(filter)
        .populate('locker', 'lockerId lockerName status')
        .populate('items.item')
        .populate('items.stock', 'stockId currentQuantity status')
        .populate('items.box', 'boxId boxNumber status')
        .sort(sort)
        .skip(skip)
        .limit(limit)
        .exec(),
      Order.countDocuments(filter).exec(),
    ]);
    return { items, total };
  }

  async updateById(id, data) {
    return Order.findByIdAndUpdate(id, data, {
      new: true,
      runValidators: true,
    })
      .populate('locker', 'lockerId lockerName status')
      .populate('items.item')
      .populate('items.stock')
      .populate('items.box', 'boxId boxNumber status')
      .populate('items.locker', 'lockerId lockerName status')
      .exec();
  }

  async findExpiredPending(now = new Date()) {
    // Expire any unpaid order past expiresAt (stock may or may not be reserved).
    return Order.find({
      status: { $in: ['CREATED', 'WAITING_PAYMENT'] },
      expiresAt: { $ne: null, $lte: now },
    }).exec();
  }

  async existsByOrderNumber(orderNumber) {
    return Boolean(
      await Order.exists({ orderNumber: String(orderNumber).toUpperCase() }),
    );
  }
}

module.exports = new OrderRepository();
