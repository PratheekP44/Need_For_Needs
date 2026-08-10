'use strict';

const Order = require('../models/Order');
// Register BLEDevice before nested populate of locker.BLEDevice.
require('../models/BLEDevice');

class OrderRepository {
  async create(data) {
    return Order.create(data);
  }

  _basePopulate(query) {
    return query
      .populate('user', 'name email phone')
      .populate('locker', 'lockerId lockerName status terminalNumber')
      .populate('items.item')
      .populate('items.stock')
      .populate('items.box', 'boxId boxNumber status')
      .populate('items.locker', 'lockerId lockerName status');
  }

  async findById(id) {
    return this._basePopulate(Order.findById(id)).exec();
  }

  async findByOrderNumber(orderNumber) {
    return this._basePopulate(
      Order.findOne({ orderNumber: String(orderNumber).toUpperCase() }),
    ).exec();
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
            model: 'BLEDevice',
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
    const scoped = {
      ...filter,
      deletedAt: filter.deletedAt !== undefined ? filter.deletedAt : null,
    };
    const [items, total] = await Promise.all([
      Order.find(scoped)
        .populate('user', 'name email phone')
        .populate('locker', 'lockerId lockerName status terminalNumber')
        .populate('items.item')
        .populate('items.stock', 'stockId currentQuantity status')
        .populate('items.box', 'boxId boxNumber status')
        .sort(sort)
        .skip(skip)
        .limit(limit)
        .exec(),
      Order.countDocuments(scoped).exec(),
    ]);
    return { items, total };
  }

  async updateById(id, data) {
    return this._basePopulate(
      Order.findByIdAndUpdate(id, data, {
        new: true,
        runValidators: true,
      }),
    ).exec();
  }

  async findExpiredPending(now = new Date()) {
    // Expire any unpaid order past expiresAt (stock may or may not be reserved).
    return Order.find({
      status: { $in: ['CREATED', 'WAITING_PAYMENT'] },
      expiresAt: { $ne: null, $lte: now },
      deletedAt: null,
    }).exec();
  }

  /**
   * Paid orders past collectionDeadline still pending collection.
   */
  async findExpiredCollectionPending(now = new Date()) {
    return Order.find({
      status: { $in: ['READY_FOR_COLLECTION', 'PAYMENT_SUCCESS'] },
      collectionDeadline: { $ne: null, $lte: now },
      deletedAt: null,
    }).exec();
  }

  async existsByOrderNumber(orderNumber) {
    return Boolean(
      await Order.exists({ orderNumber: String(orderNumber).toUpperCase() }),
    );
  }
}

module.exports = new OrderRepository();
