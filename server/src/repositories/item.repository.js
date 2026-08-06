'use strict';

const Item = require('../models/Item');

class ItemRepository {
  async create(data) {
    return Item.create(data);
  }

  async findById(id) {
    return Item.findById(id).exec();
  }

  async findByItemId(itemId) {
    return Item.findOne({ itemId: String(itemId).toUpperCase() }).exec();
  }

  async findByIdOrItemId(idOrItemId) {
    if (/^[a-fA-F0-9]{24}$/.test(String(idOrItemId))) {
      const byObjectId = await this.findById(idOrItemId);
      if (byObjectId) {
        return byObjectId;
      }
    }
    return this.findByItemId(idOrItemId);
  }

  async findByBarcode(barcode) {
    return Item.findOne({ barcode: String(barcode).trim() }).exec();
  }

  async updateById(id, data) {
    return Item.findByIdAndUpdate(id, data, {
      new: true,
      runValidators: true,
    }).exec();
  }

  async deleteById(id) {
    return Item.findByIdAndDelete(id).exec();
  }

  async list({ filter, sort, skip, limit }) {
    const [items, total] = await Promise.all([
      Item.find(filter).sort(sort).skip(skip).limit(limit).exec(),
      Item.countDocuments(filter).exec(),
    ]);
    return { items, total };
  }

  async existsByItemId(itemId, excludeId = null) {
    const query = { itemId: String(itemId).toUpperCase() };
    if (excludeId) {
      query._id = { $ne: excludeId };
    }
    return Boolean(await Item.exists(query));
  }

  async existsByBarcode(barcode, excludeId = null) {
    const query = { barcode: String(barcode).trim() };
    if (excludeId) {
      query._id = { $ne: excludeId };
    }
    return Boolean(await Item.exists(query));
  }
}

module.exports = new ItemRepository();
