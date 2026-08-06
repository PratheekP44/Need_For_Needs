'use strict';

const Box = require('../models/Box');

class BoxRepository {
  async createMany(boxes) {
    if (!boxes.length) {
      return [];
    }
    return Box.insertMany(boxes, { ordered: true });
  }

  async findById(id) {
    return Box.findById(id).populate('locker', 'lockerId lockerName status').exec();
  }

  async findByBoxId(boxId) {
    return Box.findOne({ boxId: String(boxId).toUpperCase() })
      .populate('locker', 'lockerId lockerName status')
      .exec();
  }

  async findByIdOrBoxId(idOrBoxId) {
    if (/^[a-fA-F0-9]{24}$/.test(String(idOrBoxId))) {
      const byObjectId = await this.findById(idOrBoxId);
      if (byObjectId) {
        return byObjectId;
      }
    }
    return this.findByBoxId(idOrBoxId);
  }

  async findByLocker(lockerObjectId, options = {}) {
    const query = Box.find({ locker: lockerObjectId }).sort('boxNumber');
    if (options.lean) {
      query.lean();
    }
    return query.exec();
  }

  async list({ filter, sort, skip, limit }) {
    const [items, total] = await Promise.all([
      Box.find(filter)
        .populate('locker', 'lockerId lockerName status')
        .sort(sort)
        .skip(skip)
        .limit(limit)
        .exec(),
      Box.countDocuments(filter).exec(),
    ]);

    return { items, total };
  }

  async updateById(id, data) {
    return Box.findByIdAndUpdate(id, data, {
      new: true,
      runValidators: true,
    })
      .populate('locker', 'lockerId lockerName status')
      .exec();
  }

  async deleteByLocker(lockerObjectId) {
    return Box.deleteMany({ locker: lockerObjectId }).exec();
  }

  async deleteManyByIds(ids) {
    return Box.deleteMany({ _id: { $in: ids } }).exec();
  }

  async countByLocker(lockerObjectId) {
    return Box.countDocuments({ locker: lockerObjectId }).exec();
  }

  async findTrailingBoxes(lockerObjectId, fromBoxNumber) {
    return Box.find({
      locker: lockerObjectId,
      boxNumber: { $gt: fromBoxNumber },
    })
      .sort('boxNumber')
      .exec();
  }

  async existsByBoxId(boxId, excludeId = null) {
    const query = { boxId: String(boxId).toUpperCase() };
    if (excludeId) {
      query._id = { $ne: excludeId };
    }
    return Boolean(await Box.exists(query));
  }
}

module.exports = new BoxRepository();
