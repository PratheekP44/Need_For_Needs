'use strict';

const Stock = require('../models/Stock');

class StockRepository {
  async create(data) {
    return Stock.create(data);
  }

  async findById(id) {
    return Stock.findById(id)
      .populate('item')
      .populate('locker', 'lockerId lockerName status')
      .populate('box', 'boxId boxNumber status isEmpty doorState')
      .exec();
  }

  async findByStockId(stockId) {
    return Stock.findOne({ stockId: String(stockId).toUpperCase() })
      .populate('item')
      .populate('locker', 'lockerId lockerName status')
      .populate('box', 'boxId boxNumber status isEmpty doorState')
      .exec();
  }

  async findByIdOrStockId(idOrStockId) {
    if (/^[a-fA-F0-9]{24}$/.test(String(idOrStockId))) {
      const byObjectId = await this.findById(idOrStockId);
      if (byObjectId) {
        return byObjectId;
      }
    }
    return this.findByStockId(idOrStockId);
  }

  async findByBox(boxId) {
    return Stock.findOne({ box: boxId }).exec();
  }

  async findByItem(itemId) {
    return Stock.find({ item: itemId }).exec();
  }

  /**
   * Sellable unit-box rows for a catalog item (for cart allocation).
   */
  async findSellableByItem(
    itemId,
    { lockerId = null, excludeIds = [], limit = 1 } = {},
  ) {
    const filter = {
      item: itemId,
      locker: { $exists: true, $ne: null },
      box: { $exists: true, $ne: null },
      status: { $in: ['IN_STOCK', 'LOW_STOCK'] },
      currentQuantity: { $gt: 0 },
    };
    if (lockerId) {
      filter.locker = lockerId;
    }
    if (excludeIds.length) {
      filter._id = { $nin: excludeIds };
    }
    return Stock.find(filter)
      .populate('item')
      .populate('locker', 'lockerId lockerName status')
      .populate('box', 'boxId boxNumber status isEmpty doorState')
      .sort({ createdAt: 1 })
      .limit(Math.max(1, limit))
      .exec();
  }

  async updateById(id, data) {
    return Stock.findByIdAndUpdate(id, data, {
      new: true,
      runValidators: true,
    })
      .populate('item')
      .populate('locker', 'lockerId lockerName status')
      .populate('box', 'boxId boxNumber status isEmpty doorState')
      .exec();
  }

  async deleteById(id) {
    return Stock.findByIdAndDelete(id).exec();
  }

  async list({ filter, sort, skip, limit }) {
    const [items, total] = await Promise.all([
      Stock.find(filter)
        .populate('item')
        .populate('locker', 'lockerId lockerName status')
        .populate('box', 'boxId boxNumber status isEmpty doorState')
        .sort(sort)
        .skip(skip)
        .limit(limit)
        .exec(),
      Stock.countDocuments(filter).exec(),
    ]);
    return { items, total };
  }

  async existsByStockId(stockId, excludeId = null) {
    const query = { stockId: String(stockId).toUpperCase() };
    if (excludeId) {
      query._id = { $ne: excludeId };
    }
    return Boolean(await Stock.exists(query));
  }

  async existsByBox(boxId, excludeId = null) {
    const query = { box: boxId };
    if (excludeId) {
      query._id = { $ne: excludeId };
    }
    return Boolean(await Stock.exists(query));
  }

  async countByItem(itemId) {
    return Stock.countDocuments({ item: itemId }).exec();
  }

  async findByLocker(lockerId) {
    return Stock.find({ locker: lockerId })
      .populate('item')
      .populate('locker', 'lockerId lockerName status')
      .populate('box', 'boxId boxNumber status isEmpty doorState')
      .exec();
  }

  async findByIdRaw(id) {
    return Stock.findById(id).populate('item').exec();
  }

  /**
   * Atomically reserve quantity if enough stock is available.
   */
  async reserveQuantity(stockId, quantity) {
    return Stock.findOneAndUpdate(
      {
        _id: stockId,
        currentQuantity: { $gte: quantity },
        status: { $nin: ['DISABLED', 'EXPIRED'] },
      },
      { $inc: { currentQuantity: -Math.abs(quantity) } },
      { new: true, runValidators: true },
    )
      .populate('item')
      .exec();
  }

  /**
   * Release previously reserved quantity back to stock.
   */
  async releaseQuantity(stockId, quantity) {
    const stock = await Stock.findById(stockId).exec();
    if (!stock) {
      return null;
    }

    const nextQty = Math.min(
      stock.maximumQuantity,
      stock.currentQuantity + Math.abs(quantity),
    );

    return Stock.findOneAndUpdate(
      { _id: stockId },
      { $set: { currentQuantity: nextQty } },
      { new: true, runValidators: true },
    )
      .populate('item')
      .exec();
  }
}

module.exports = new StockRepository();
