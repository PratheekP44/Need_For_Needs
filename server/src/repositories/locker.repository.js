'use strict';

const Locker = require('../models/Locker');

class LockerRepository {
  async create(data) {
    return Locker.create(data);
  }

  async findById(id) {
    return Locker.findById(id).exec();
  }

  async findByLockerId(lockerId) {
    return Locker.findOne({ lockerId: String(lockerId).toUpperCase() }).exec();
  }

  async findByIdOrLockerId(idOrLockerId) {
    if (/^[a-fA-F0-9]{24}$/.test(String(idOrLockerId))) {
      const byObjectId = await this.findById(idOrLockerId);
      if (byObjectId) {
        return byObjectId;
      }
    }
    return this.findByLockerId(idOrLockerId);
  }

  async updateById(id, data) {
    return Locker.findByIdAndUpdate(id, data, {
      new: true,
      runValidators: true,
    }).exec();
  }

  async deleteById(id) {
    return Locker.findByIdAndDelete(id).exec();
  }

  async list({ filter, sort, skip, limit }) {
    const [items, total] = await Promise.all([
      Locker.find(filter).sort(sort).skip(skip).limit(limit).exec(),
      Locker.countDocuments(filter).exec(),
    ]);

    return { items, total };
  }

  async existsByLockerId(lockerId, excludeId = null) {
    const query = { lockerId: String(lockerId).toUpperCase() };
    if (excludeId) {
      query._id = { $ne: excludeId };
    }
    return Boolean(await Locker.exists(query));
  }

  async existsByTerminalNumber(terminalNumber, excludeId = null) {
    const query = { terminalNumber: Number(terminalNumber) };
    if (excludeId) {
      query._id = { $ne: excludeId };
    }
    return Boolean(await Locker.exists(query));
  }
}

module.exports = new LockerRepository();
