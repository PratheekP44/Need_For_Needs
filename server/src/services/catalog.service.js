'use strict';

const mongoose = require('mongoose');
const Item = require('../models/Item');
const Order = require('../models/Order');
const { ITEM_CATEGORIES } = require('../models/enums');
const {
  aggregateCatalogByItem,
  formatCatalogProduct,
} = require('./stock.service');
const AppError = require('../utils/AppError');

function titleCaseCategory(id) {
  return String(id)
    .toLowerCase()
    .split('_')
    .map((w) => (w ? `${w[0].toUpperCase()}${w.slice(1)}` : w))
    .join(' ');
}

class CatalogService {
  async listCategories() {
    const counts = await Item.aggregate([
      { $match: { isActive: true } },
      { $group: { _id: '$category', itemCount: { $sum: 1 } } },
    ]);
    const countMap = new Map(counts.map((c) => [c._id, c.itemCount]));

    return {
      categories: ITEM_CATEGORIES.map((id) => ({
        id,
        name: titleCaseCategory(id),
        itemCount: countMap.get(id) || 0,
      })),
    };
  }

  async getHomeFeed(query = {}) {
    const limit = Math.min(Math.max(Number(query.limit) || 12, 1), 40);
    let lockerMatch = {};
    if (query.locker) {
      if (!mongoose.isValidObjectId(query.locker)) {
        throw new AppError('Invalid locker id', 400);
      }
      lockerMatch = { locker: new mongoose.Types.ObjectId(query.locker) };
    }

    const [newest, recommended, popularByItem] = await Promise.all([
      aggregateCatalogByItem({
        match: lockerMatch,
        page: 1,
        limit,
        sort: 'newest',
      }),
      aggregateCatalogByItem({
        match: lockerMatch,
        page: 1,
        limit,
        sort: '-availableQuantity',
      }),
      Order.aggregate([
        { $match: { paymentStatus: 'SUCCESS' } },
        { $unwind: '$items' },
        {
          $group: {
            _id: '$items.item',
            sold: { $sum: '$items.quantity' },
          },
        },
        { $sort: { sold: -1 } },
        { $limit: limit },
      ]),
    ]);

    const popularIds = popularByItem.map((r) => r._id).filter(Boolean);
    let popularRows = [];
    if (popularIds.length) {
      const { rows } = await aggregateCatalogByItem({
        match: {
          ...lockerMatch,
          item: { $in: popularIds },
        },
        page: 1,
        limit: popularIds.length,
      });
      const byId = new Map(rows.map((r) => [String(r.id), r]));
      popularRows = popularIds
        .map((id) => byId.get(String(id)))
        .filter(Boolean);
    }
    if (popularRows.length < Math.min(4, recommended.rows.length)) {
      const used = new Set(popularRows.map((r) => String(r.id)));
      for (const row of recommended.rows) {
        if (used.has(String(row.id))) continue;
        popularRows.push(row);
        if (popularRows.length >= limit) break;
      }
    }

    const categories = await this.listCategories();

    return {
      sections: [
        {
          key: 'popular',
          title: 'Popular',
          items: popularRows.slice(0, limit),
        },
        {
          key: 'newest',
          title: 'Recently added',
          items: newest.rows,
        },
        {
          key: 'recommended',
          title: 'Recommended',
          items: recommended.rows,
        },
      ],
      categories: categories.categories,
    };
  }

  async getBuyAgain(userId, limit = 8) {
    if (!userId) return { items: [] };

    const recentOrders = await Order.find({
      user: userId,
      paymentStatus: 'SUCCESS',
    })
      .sort('-createdAt')
      .limit(10)
      .exec();

    const itemIds = [];
    const seen = new Set();
    for (const order of recentOrders) {
      for (const line of order.items || []) {
        const id = String(line.item || '');
        if (!id || seen.has(id)) continue;
        seen.add(id);
        itemIds.push(id);
        if (itemIds.length >= limit) break;
      }
      if (itemIds.length >= limit) break;
    }

    if (!itemIds.length) return { items: [] };

    const objectIds = itemIds
      .filter((id) => mongoose.isValidObjectId(id))
      .map((id) => new mongoose.Types.ObjectId(id));

    const { rows } = await aggregateCatalogByItem({
      match: { item: { $in: objectIds } },
      page: 1,
      limit: itemIds.length,
    });
    const byId = new Map(rows.map((r) => [String(r.id), r]));
    const ordered = itemIds.map((id) => byId.get(String(id))).filter(Boolean);
    return { items: ordered };
  }

  async getProduct(itemId) {
    const stockService = require('./stock.service');
    return stockService.getCatalogProductByItemId(itemId);
  }
}

module.exports = new CatalogService();
module.exports.formatCatalogProduct = formatCatalogProduct;
