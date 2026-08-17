'use strict';

const mongoose = require('mongoose');
const Stock = require('../models/Stock');
const stockRepository = require('../repositories/stock.repository');
const itemRepository = require('../repositories/item.repository');
const boxRepository = require('../repositories/box.repository');
const lockerRepository = require('../repositories/locker.repository');
const activityService = require('./activity.service');
const { formatItem } = require('./item.service');
const AppError = require('../utils/AppError');
const { parseListQuery, buildPagination } = require('../utils/query');
const {
  deriveStockStatus,
  deriveBoxOccupancyFromStock,
} = require('../utils/stockStatus');

function formatNested(doc, fields) {
  if (!doc) return null;
  if (typeof doc !== 'object') return doc;
  const out = { id: doc._id || doc.id };
  fields.forEach((field) => {
    if (doc[field] !== undefined) out[field] = doc[field];
  });
  return out;
}

function availabilityFromStock(stock) {
  if (!stock.locker || !stock.box || !stock.item) {
    return 'unavailable';
  }
  const qty = Number(stock.currentQuantity) || 0;
  const status = String(stock.status || '').toUpperCase();
  if (['DISABLED', 'EXPIRED', 'OUT_OF_STOCK'].includes(status) || qty <= 0) {
    return 'unavailable';
  }
  return 'available';
}

/**
 * Customer catalog product — one entry per Item.
 * No box fields; availableQuantity = count of sellable stock records.
 */
function formatCatalogProduct(row) {
  const itemDoc = row.item || {};
  const item = formatItem(itemDoc);
  const availableQuantity = Number(row.availableQuantity) || 0;
  const locker = row.locker
    ? {
        id: row.locker._id || row.locker.id,
        lockerId: row.locker.lockerId,
        lockerName: row.locker.lockerName,
        status: row.locker.status,
      }
    : null;

  return {
    id: item.id || itemDoc._id,
    itemId: item.itemId,
    grouped: true,
    quantity: availableQuantity,
    availableQuantity,
    availability: availableQuantity > 0 ? 'available' : 'unavailable',
    item,
    name: item.name,
    price: item.sellingPrice,
    imageUrl: item.imageUrl,
    category: item.category,
    description: item.description,
    locker,
    lockerId: locker?.id || null,
    lockerName: locker?.lockerName || null,
  };
}

function sellableStockMatch(extra = {}) {
  return {
    locker: { $exists: true, $ne: null },
    box: { $exists: true, $ne: null },
    status: { $in: ['IN_STOCK', 'LOW_STOCK'] },
    currentQuantity: { $gt: 0 },
    ...extra,
  };
}

/**
 * MongoDB aggregation: group sellable stock rows by product (item) id.
 * Box data is intentionally excluded from the customer catalog response.
 */
async function aggregateCatalogByItem({
  match = {},
  itemMatch = null,
  page = 1,
  limit = 40,
  sort = '-availableQuantity',
} = {}) {
  const skip = (Math.max(page, 1) - 1) * limit;
  const pipeline = [
    { $match: sellableStockMatch(match) },
    {
      $lookup: {
        from: 'items',
        localField: 'item',
        foreignField: '_id',
        as: 'item',
      },
    },
    { $unwind: '$item' },
    {
      $match: {
        'item.isActive': true,
        ...(itemMatch || {}),
      },
    },
    {
      $lookup: {
        from: 'lockers',
        localField: 'locker',
        foreignField: '_id',
        as: 'lockerDoc',
      },
    },
    {
      $group: {
        _id: '$item._id',
        availableQuantity: { $sum: 1 },
        item: { $first: '$item' },
        lockers: { $push: { $arrayElemAt: ['$lockerDoc', 0] } },
        updatedAt: { $max: '$updatedAt' },
        createdAt: { $max: '$createdAt' },
      },
    },
  ];

  let sortSpec = { availableQuantity: -1, updatedAt: -1 };
  if (sort === 'newest' || sort === '-createdAt') sortSpec = { createdAt: -1 };
  if (sort === 'oldest' || sort === 'createdAt') sortSpec = { createdAt: 1 };
  if (sort === 'name') sortSpec = { 'item.name': 1 };
  if (sort === 'price' || sort === 'sellingPrice') {
    sortSpec = { 'item.sellingPrice': 1 };
  }
  if (sort === '-price') sortSpec = { 'item.sellingPrice': -1 };

  pipeline.push({ $sort: sortSpec });
  pipeline.push({
    $facet: {
      rows: [{ $skip: skip }, { $limit: limit }],
      total: [{ $count: 'count' }],
    },
  });

  const counted = await Stock.aggregate(pipeline).exec();
  const facet = counted[0] || { rows: [], total: [] };
  const total = facet.total[0]?.count || 0;

  const rows = (facet.rows || []).map((row) => {
    const counts = new Map();
    for (const locker of row.lockers || []) {
      if (!locker || !locker._id) continue;
      const key = String(locker._id);
      const prev = counts.get(key) || { locker, count: 0 };
      prev.count += 1;
      counts.set(key, prev);
    }
    let best = null;
    for (const entry of counts.values()) {
      if (!best || entry.count > best.count) best = entry;
    }
    return formatCatalogProduct({
      item: row.item,
      availableQuantity: row.availableQuantity,
      locker: best?.locker || null,
    });
  });

  return { rows, total, page, limit };
}

function formatStock(stock) {
  const base = typeof stock.toPublicObject === 'function'
    ? stock.toPublicObject()
    : {
        id: stock._id,
        stockId: stock.stockId,
        currentQuantity: stock.currentQuantity,
        maximumQuantity: stock.maximumQuantity,
        reorderLevel: stock.reorderLevel,
        expiryDate: stock.expiryDate,
        batchNumber: stock.batchNumber,
        supplierName: stock.supplierName,
        purchaseDate: stock.purchaseDate,
        status: stock.status,
        lastRestocked: stock.lastRestocked,
        createdAt: stock.createdAt,
        updatedAt: stock.updatedAt,
      };

  const locker = formatNested(stock.locker, ['lockerId', 'lockerName', 'status']);
  const box = formatNested(stock.box, ['boxId', 'boxNumber', 'status', 'isEmpty', 'doorState']);
  const item =
    stock.item && typeof stock.item === 'object' && stock.item.name
      ? formatItem(stock.item)
      : stock.item;

  // Flat catalog fields so Flutter never has to dig nested nulls for cart mapping.
  return {
    ...base,
    locker,
    box,
    item,
    lockerId: locker?.id || null,
    lockerName: locker?.lockerName || null,
    boxId: box?.id || null,
    boxNumber: box?.boxNumber ?? null,
    quantity: Number(stock.currentQuantity) || 0,
    availability: availabilityFromStock(stock),
  };
}

async function syncBoxOccupancy(boxDoc, stockLike) {
  if (!boxDoc) return;
  if (boxDoc.status === 'MAINTENANCE' || boxDoc.status === 'FAULT') {
    return;
  }

  const occupancy = deriveBoxOccupancyFromStock(stockLike);
  await boxRepository.updateById(boxDoc._id || boxDoc, occupancy);
}

class StockService {
  /**
   * Admin stocking: a box is assignable when it has no stock row and is not
   * blocked (same definition as GET /boxes?unassigned=true).
   */
  assertBoxAssignable(box) {
    if (!box) {
      throw new AppError('Box not found', 404);
    }
    if (['MAINTENANCE', 'FAULT', 'RESERVED'].includes(box.status)) {
      throw new AppError(
        `Selected box is unavailable (status ${box.status})`,
        409,
      );
    }
    if (box.isEmpty === false && box.status !== 'EMPTY') {
      throw new AppError('Box already occupied', 409);
    }
  }

  async resolveBox(boxRef) {
    const box = await boxRepository.findByIdOrBoxId(boxRef);
    if (!box) {
      throw new AppError('Box not found', 404);
    }
    return box;
  }

  async resolveItem(itemRef) {
    const item = await itemRepository.findByIdOrItemId(itemRef);
    if (!item) {
      throw new AppError('Item not found', 404);
    }
    if (!item.isActive) {
      throw new AppError('Item is inactive', 400);
    }
    return item;
  }

  async resolveLocker(lockerRef, expectedId = null) {
    let locker = null;
    if (lockerRef) {
      locker = await lockerRepository.findByIdOrLockerId(lockerRef);
      if (!locker) {
        throw new AppError('Locker not found', 404);
      }
    }
    if (expectedId && locker && String(locker._id) !== String(expectedId)) {
      throw new AppError('Locker does not match the selected box', 400);
    }
    return locker;
  }

  computeStatus(payload, currentStatus) {
    if (payload.status === 'DISABLED') {
      return 'DISABLED';
    }
    return deriveStockStatus({
      currentQuantity: payload.currentQuantity,
      reorderLevel: payload.reorderLevel,
      expiryDate: payload.expiryDate,
      currentStatus: payload.status === 'DISABLED' ? 'DISABLED' : currentStatus,
    });
  }

  async assignStock(payload, adminId) {
    const box = await this.resolveBox(payload.box);
    const item = await this.resolveItem(payload.item);
    const lockerIdFromBox = box.locker?._id || box.locker;
    const locker = await this.resolveLocker(payload.locker || lockerIdFromBox, lockerIdFromBox);

    this.assertBoxAssignable(box);

    // One box → one stock record (unique index + explicit check).
    if (await stockRepository.existsByBox(box._id)) {
      throw new AppError('Box already occupied', 409);
    }

    // Physical unit-box model: exactly one item per box.
    const requestedQty = payload.currentQuantity;
    if (
      requestedQty !== undefined &&
      requestedQty !== null &&
      Number(requestedQty) > 1
    ) {
      throw new AppError(
        'Each box holds exactly one physical item. Use POST /stock/batch to stock multiple boxes.',
        400,
      );
    }

    const currentQuantity = 1;
    const maximumQuantity = 1;
    const reorderLevel = Number(payload.reorderLevel) || 0;

    const stamp = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
    const stockId = String(payload.stockId || `STK-${stamp}`).trim().toUpperCase();
    if (await stockRepository.existsByStockId(stockId)) {
      throw new AppError('Stock ID already exists', 409);
    }

    const status = this.computeStatus(
      {
        currentQuantity,
        reorderLevel,
        expiryDate: payload.expiryDate || null,
        status: payload.status,
      },
      'OUT_OF_STOCK',
    );

    const stock = await stockRepository.create({
      stockId,
      locker: locker._id,
      box: box._id,
      item: item._id,
      currentQuantity,
      maximumQuantity,
      reorderLevel,
      expiryDate: payload.expiryDate || null,
      batchNumber: payload.batchNumber || '',
      supplierName: payload.supplierName || '',
      purchaseDate: payload.purchaseDate || null,
      status,
      lastRestocked: currentQuantity > 0 ? new Date() : null,
    });

    await syncBoxOccupancy(box, stock);

    await activityService.log({
      action: 'assign_stock',
      entity: 'Stock',
      entityId: stock._id,
      adminId,
      metadata: {
        stockId,
        boxId: box.boxId,
        itemId: item.itemId,
        unitBox: true,
      },
    });

    const populated = await stockRepository.findById(stock._id);
    return formatStock(populated);
  }

  /**
   * Stock N physical units into N distinct empty boxes.
   * Creates N stock records with quantity=1 each (never qty>1 in one box).
   */
  async assignStockBatch(payload, adminId) {
    const item = await this.resolveItem(payload.item);
    const quantity = Number(payload.quantity);
    const boxRefs = Array.isArray(payload.boxes) ? payload.boxes : [];

    if (!(quantity >= 1)) {
      throw new AppError('Invalid box selection: quantity must be at least 1', 400);
    }
    if (boxRefs.length !== quantity) {
      throw new AppError(
        `Invalid box selection: select exactly ${quantity} empty box(es); got ${boxRefs.length}`,
        400,
      );
    }

    const uniqueKeys = new Set(boxRefs.map((b) => String(b).trim().toLowerCase()));
    if (uniqueKeys.size !== boxRefs.length) {
      throw new AppError('Invalid box selection: duplicate boxes are not allowed', 400);
    }

    const resolvedBoxes = [];
    for (const ref of boxRefs) {
      const box = await this.resolveBox(ref);
      this.assertBoxAssignable(box);
      if (await stockRepository.existsByBox(box._id)) {
        throw new AppError(
          `Box already occupied (${box.boxId || box.boxNumber || box._id})`,
          409,
        );
      }
      resolvedBoxes.push(box);
    }

    // Re-check uniqueness by ObjectId after resolve (aliases could collide).
    const resolvedIds = new Set(resolvedBoxes.map((b) => String(b._id)));
    if (resolvedIds.size !== resolvedBoxes.length) {
      throw new AppError('Invalid box selection: duplicate boxes are not allowed', 400);
    }

    const stocks = [];
    for (let i = 0; i < resolvedBoxes.length; i += 1) {
      const box = resolvedBoxes[i];
      const lockerIdFromBox = box.locker?._id || box.locker;
      const stock = await this.assignStock(
        {
          item: item._id,
          box: box._id,
          locker: lockerIdFromBox,
          currentQuantity: 1,
          maximumQuantity: 1,
          reorderLevel: payload.reorderLevel ?? 0,
          expiryDate: payload.expiryDate || null,
          batchNumber: payload.batchNumber || '',
          supplierName: payload.supplierName || '',
          purchaseDate: payload.purchaseDate || null,
          stockId: `STK-${Date.now()}-${i}-${Math.random().toString(16).slice(2, 6)}`,
        },
        adminId,
      );
      stocks.push(stock);
    }

    await activityService.log({
      action: 'assign_stock_batch',
      entity: 'Stock',
      entityId: item._id,
      adminId,
      metadata: {
        itemId: item.itemId,
        quantity,
        boxIds: resolvedBoxes.map((b) => b.boxId || String(b._id)),
        stockIds: stocks.map((s) => s.stockId),
      },
    });

    return {
      stocks,
      count: stocks.length,
      item: {
        id: item._id,
        itemId: item.itemId,
        name: item.name,
      },
    };
  }

  async listStock(query) {
    const listQuery = parseListQuery(query, {
      defaultSort: '-createdAt',
      allowedSortFields: [
        'createdAt',
        'updatedAt',
        'currentQuantity',
        'status',
        'stockId',
      ],
      filterFields: {
        status: 'status',
        locker: 'locker',
        box: 'box',
        item: 'item',
        stockId: 'stockId',
      },
      searchFields: ['stockId', 'batchNumber', 'supplierName'],
    });

    if (listQuery.filter.stockId) {
      listQuery.filter.stockId = String(listQuery.filter.stockId).toUpperCase();
    }

    ['locker', 'box', 'item'].forEach((field) => {
      if (listQuery.filter[field] && !mongoose.isValidObjectId(listQuery.filter[field])) {
        throw new AppError(`Invalid ${field} filter. Use Mongo ObjectId.`, 400);
      }
    });

    // Customer catalog: one product per item (count of sellable stock rows).
    // Admin inventory omits availability=available and stays per-stock.
    if (query.availability === 'available') {
      const match = {};
      if (listQuery.filter.locker) {
        match.locker = listQuery.filter.locker;
      }
      if (listQuery.filter.item) {
        match.item = listQuery.filter.item;
      }

      const itemMatch = {};
      if (query.category) itemMatch['item.category'] = query.category;
      if (query.brand) {
        itemMatch['item.brand'] = new RegExp(String(query.brand), 'i');
      }
      if (query.barcode) {
        itemMatch['item.barcode'] = String(query.barcode).trim();
      }
      const itemSearch = query.searchItem || query.search;
      if (itemSearch) {
        const re = new RegExp(String(itemSearch), 'i');
        itemMatch.$or = [
          { 'item.name': re },
          { 'item.brand': re },
          { 'item.barcode': re },
          { 'item.itemId': re },
          { 'item.description': re },
          { 'item.tags': re },
        ];
      }
      if (query.minPrice !== undefined && query.minPrice !== '') {
        itemMatch['item.sellingPrice'] = {
          ...(itemMatch['item.sellingPrice'] || {}),
          $gte: Number(query.minPrice),
        };
      }
      if (query.maxPrice !== undefined && query.maxPrice !== '') {
        itemMatch['item.sellingPrice'] = {
          ...(itemMatch['item.sellingPrice'] || {}),
          $lte: Number(query.maxPrice),
        };
      }

      const { rows, total } = await aggregateCatalogByItem({
        match,
        itemMatch: Object.keys(itemMatch).length ? itemMatch : null,
        page: listQuery.page,
        limit: listQuery.limit,
        sort: query.sort || '-availableQuantity',
      });

      return {
        stock: rows,
        pagination: buildPagination({
          page: listQuery.page,
          limit: listQuery.limit,
          total,
        }),
      };
    }

    if (query.availability === 'unavailable') {
      listQuery.filter.status = { $in: ['OUT_OF_STOCK', 'EXPIRED', 'DISABLED'] };
    }

    // Default catalog responses hide orphan stock missing box/locker.
    if (query.includeOrphans !== 'true' && query.includeOrphans !== '1') {
      if (!listQuery.filter.locker) {
        listQuery.filter.locker = { $exists: true, $ne: null };
      }
      if (!listQuery.filter.box) {
        listQuery.filter.box = { $exists: true, $ne: null };
      }
    }

    if (query.sort === 'newest') listQuery.sort = '-createdAt';
    if (query.sort === 'oldest') listQuery.sort = 'createdAt';
    if (query.sort === 'quantity') listQuery.sort = 'currentQuantity';
    if (query.sort === '-quantity') listQuery.sort = '-currentQuantity';

    // Item-oriented search (name/category/tags) — do not also AND stock-field $or.
    if (query.searchItem || query.search || query.category || query.brand || query.barcode) {
      if (query.search || query.searchItem) {
        delete listQuery.filter.$or;
      }
      const itemFilter = {};
      if (query.category) itemFilter.category = query.category;
      if (query.brand) itemFilter.brand = new RegExp(String(query.brand), 'i');
      if (query.barcode) itemFilter.barcode = String(query.barcode).trim();
      const itemSearch = query.searchItem || query.search;
      if (itemSearch) {
        itemFilter.$or = [
          { name: new RegExp(String(itemSearch), 'i') },
          { brand: new RegExp(String(itemSearch), 'i') },
          { barcode: new RegExp(String(itemSearch), 'i') },
          { itemId: new RegExp(String(itemSearch), 'i') },
          { description: new RegExp(String(itemSearch), 'i') },
          { tags: new RegExp(String(itemSearch), 'i') },
        ];
      }
      const matchedItems = await itemRepository.list({
        filter: itemFilter,
        sort: 'name',
        skip: 0,
        limit: 500,
      });
      const ids = matchedItems.items.map((item) => item._id);
      listQuery.filter.item = { $in: ids };
    }

    if (query.minPrice !== undefined || query.maxPrice !== undefined) {
      const priceFilter = {};
      if (query.minPrice !== undefined && query.minPrice !== '') {
        priceFilter.$gte = Number(query.minPrice);
      }
      if (query.maxPrice !== undefined && query.maxPrice !== '') {
        priceFilter.$lte = Number(query.maxPrice);
      }
      const priced = await itemRepository.list({
        filter: { sellingPrice: priceFilter },
        sort: 'name',
        skip: 0,
        limit: 1000,
      });
      const pricedIds = priced.items.map((item) => item._id);
      if (listQuery.filter.item && listQuery.filter.item.$in) {
        const set = new Set(pricedIds.map(String));
        listQuery.filter.item.$in = listQuery.filter.item.$in.filter((id) =>
          set.has(String(id)),
        );
      } else {
        listQuery.filter.item = { $in: pricedIds };
      }
    }

    const { items, total } = await stockRepository.list(listQuery);

    return {
      stock: items.map((row) => formatStock(row)),
      pagination: buildPagination({
        page: listQuery.page,
        limit: listQuery.limit,
        total,
      }),
    };
  }

  /**
   * Phase 24 — physical box inventory for Admin.
   * Returns one row per box (including empty). Never aggregates item quantities.
   */
  async listPhysicalInventory(query = {}) {
    let locker = null;
    if (query.locker) {
      locker = await lockerRepository.findByIdOrLockerId(query.locker);
      if (!locker) {
        throw new AppError('Locker not found', 404);
      }
    } else {
      // Prefer Campus Gate when present; otherwise first locker by name.
      const listed = await lockerRepository.list({
        filter: {},
        sort: 'lockerName',
        skip: 0,
        limit: 50,
      });
      const items = listed.items || [];
      locker =
        items.find(
          (l) =>
            String(l.lockerId || '').toUpperCase() === 'LCK-DEMO-06742' ||
            /campus\s*gate/i.test(String(l.lockerName || '')),
        ) || items[0] || null;
      if (!locker) {
        return {
          locker: null,
          summary: { totalBoxes: 0, occupiedBoxes: 0, emptyBoxes: 0 },
          boxes: [],
        };
      }
    }

    const boxes = await boxRepository.findByLocker(locker._id);
    const stocks = await stockRepository.findByLocker(locker._id);
    const stockByBoxId = new Map();
    for (const stock of stocks) {
      const boxKey = String(stock.box?._id || stock.box || '');
      if (!boxKey) continue;
      // One stock per box — keep first if duplicates somehow exist.
      if (!stockByBoxId.has(boxKey)) {
        stockByBoxId.set(boxKey, stock);
      }
    }

    const occupancyFilter = String(query.occupancy || 'all').toLowerCase();
    const itemFilter = query.item ? String(query.item) : null;

    const rows = [];

    for (const box of boxes) {
      const stock = stockByBoxId.get(String(box._id));
      const qty = stock ? Number(stock.currentQuantity) || 0 : 0;
      const occupied = Boolean(stock && stock.item && qty > 0);

      if (occupancyFilter === 'occupied' && !occupied) continue;
      if (occupancyFilter === 'empty' && occupied) continue;

      if (itemFilter) {
        const itemId = stock?.item?._id || stock?.item;
        const itemCode = stock?.item?.itemId;
        const match =
          String(itemId) === itemFilter ||
          String(itemCode || '').toUpperCase() === itemFilter.toUpperCase();
        if (!match) continue;
      }

      const itemDoc =
        stock?.item && typeof stock.item === 'object' ? stock.item : null;

      rows.push({
        boxId: box._id,
        boxCode: box.boxId,
        boxNumber: box.boxNumber,
        boxStatus: box.status,
        isEmpty: !occupied,
        occupancy: occupied ? 'Occupied' : 'Empty',
        quantity: occupied ? 1 : 0,
        stockId: stock?._id || null,
        stockCode: stock?.stockId || '',
        stockStatus: stock?.status || null,
        item: occupied && itemDoc
          ? formatItem(itemDoc)
          : occupied && stock?.item
            ? stock.item
            : null,
        itemId: occupied ? itemDoc?._id || stock?.item || null : null,
        itemName: occupied
          ? itemDoc?.name || 'Item'
          : null,
        imageUrl: occupied
          ? (itemDoc ? formatItem(itemDoc).imageUrl : '') || ''
          : '',
        price: occupied ? Number(itemDoc?.sellingPrice) || 0 : 0,
        locker: {
          id: locker._id,
          lockerId: locker.lockerId,
          lockerName: locker.lockerName,
          status: locker.status,
          terminalNumber: locker.terminalNumber,
        },
      });
    }

    // Summary is always for the full locker (not the filtered subset).
    const totalBoxes = boxes.length;
    const fullOccupied = [...stockByBoxId.values()].filter(
      (s) => s.item && Number(s.currentQuantity) > 0,
    ).length;

    return {
      locker: {
        id: locker._id,
        lockerId: locker.lockerId,
        lockerName: locker.lockerName,
        status: locker.status,
        terminalNumber: locker.terminalNumber,
        totalBoxes: locker.totalBoxes,
      },
      summary: {
        totalBoxes,
        occupiedBoxes: fullOccupied,
        emptyBoxes: totalBoxes - fullOccupied,
      },
      boxes: rows,
    };
  }

  async getCatalogProductByItemId(itemId) {
    const item = await itemRepository.findByIdOrItemId(itemId);
    if (!item || !item.isActive) {
      throw new AppError('Product not found', 404);
    }
    const { rows } = await aggregateCatalogByItem({
      match: { item: item._id },
      page: 1,
      limit: 1,
    });
    if (rows.length) {
      return rows[0];
    }
    return formatCatalogProduct({
      item,
      availableQuantity: 0,
      locker: null,
    });
  }

  async getStockById(id) {
    // Customer product details use Item id (catalog product id).
    if (mongoose.isValidObjectId(id) || String(id).startsWith('ITM-')) {
      const asItem = await itemRepository.findByIdOrItemId(id);
      if (asItem) {
        return this.getCatalogProductByItemId(String(asItem._id));
      }
    }

    const stock = await stockRepository.findByIdOrStockId(id);
    if (!stock) {
      throw new AppError('Stock not found', 404);
    }
    return formatStock(stock);
  }

  async updateStock(id, payload, adminId) {
    const stock = await stockRepository.findByIdOrStockId(id);
    if (!stock) {
      throw new AppError('Stock not found', 404);
    }

    const updates = { ...payload };
    // Box / locker / item reassignment must go through moveStock / re-assign.
    delete updates.box;
    delete updates.locker;
    delete updates.item;

    if (updates.stockId) {
      updates.stockId = String(updates.stockId).trim().toUpperCase();
      if (
        updates.stockId !== stock.stockId &&
        (await stockRepository.existsByStockId(updates.stockId, stock._id))
      ) {
        throw new AppError('Stock ID already exists', 409);
      }
    }

    const nextQty =
      updates.currentQuantity !== undefined
        ? Number(updates.currentQuantity)
        : stock.currentQuantity;
    const nextMax =
      updates.maximumQuantity !== undefined
        ? Number(updates.maximumQuantity)
        : stock.maximumQuantity;

    if (nextQty > 1 || nextMax > 1) {
      throw new AppError(
        'Each box holds exactly one physical item (quantity must be 0 or 1)',
        400,
      );
    }
    const nextReorder =
      updates.reorderLevel !== undefined
        ? Number(updates.reorderLevel)
        : stock.reorderLevel;
    const nextExpiry =
      updates.expiryDate !== undefined ? updates.expiryDate : stock.expiryDate;

    if (nextQty > nextMax) {
      throw new AppError('Current quantity cannot exceed maximumQuantity', 400);
    }

    updates.currentQuantity = nextQty;
    updates.maximumQuantity = nextMax;
    updates.reorderLevel = nextReorder;
    updates.status = this.computeStatus(
      {
        currentQuantity: nextQty,
        reorderLevel: nextReorder,
        expiryDate: nextExpiry,
        status: updates.status || stock.status,
      },
      updates.status || stock.status,
    );

    if (
      updates.currentQuantity !== undefined &&
      Number(updates.currentQuantity) > Number(stock.currentQuantity)
    ) {
      updates.lastRestocked = new Date();
    }

    const updated = await stockRepository.updateById(stock._id, updates);
    const boxId = stock.box?._id || stock.box;
    const box = await boxRepository.findById(boxId);
    await syncBoxOccupancy(box, updated);

    await activityService.log({
      action: 'update',
      entity: 'Stock',
      entityId: updated._id,
      adminId,
      metadata: { stockId: updated.stockId },
    });

    return formatStock(updated);
  }

  async restock(id, payload, adminId) {
    const stock = await stockRepository.findByIdOrStockId(id);
    if (!stock) {
      throw new AppError('Stock not found', 404);
    }

    let nextQty = stock.currentQuantity;
    if (payload.setQuantity !== undefined) {
      nextQty = Number(payload.setQuantity);
    } else if (payload.addQuantity !== undefined) {
      nextQty = stock.currentQuantity + Number(payload.addQuantity);
    } else {
      throw new AppError('Provide addQuantity or setQuantity', 400);
    }

    if (nextQty < 0) {
      throw new AppError('Quantity cannot be negative', 400);
    }
    if (nextQty > 1) {
      throw new AppError(
        'Each box holds exactly one physical item. To stock more units, assign additional empty boxes.',
        400,
      );
    }
    if (nextQty > stock.maximumQuantity) {
      throw new AppError('Quantity cannot exceed maximumQuantity', 400);
    }

    const status = this.computeStatus(
      {
        currentQuantity: nextQty,
        reorderLevel: stock.reorderLevel,
        expiryDate: payload.expiryDate !== undefined ? payload.expiryDate : stock.expiryDate,
        status: stock.status,
      },
      stock.status,
    );

    const updates = {
      currentQuantity: nextQty,
      status,
      lastRestocked: new Date(),
    };
    if (payload.batchNumber !== undefined) updates.batchNumber = payload.batchNumber;
    if (payload.supplierName !== undefined) updates.supplierName = payload.supplierName;
    if (payload.expiryDate !== undefined) updates.expiryDate = payload.expiryDate;
    if (payload.purchaseDate !== undefined) updates.purchaseDate = payload.purchaseDate;

    const updated = await stockRepository.updateById(stock._id, updates);
    const box = await boxRepository.findById(stock.box?._id || stock.box);
    await syncBoxOccupancy(box, updated);

    await activityService.log({
      action: 'restock',
      entity: 'Stock',
      entityId: updated._id,
      adminId,
      metadata: {
        stockId: updated.stockId,
        previousQuantity: stock.currentQuantity,
        currentQuantity: nextQty,
      },
    });

    return formatStock(updated);
  }

  async moveStock(id, payload, adminId) {
    const stock = await stockRepository.findByIdOrStockId(id);
    if (!stock) {
      throw new AppError('Stock not found', 404);
    }

    const targetBox = await this.resolveBox(payload.toBox || payload.box);
    const targetLockerId = targetBox.locker?._id || targetBox.locker;
    const currentBoxId = String(stock.box?._id || stock.box);

    if (String(targetBox._id) === currentBoxId) {
      throw new AppError('Stock is already in the target box', 400);
    }

    if (['MAINTENANCE', 'FAULT', 'RESERVED'].includes(targetBox.status)) {
      throw new AppError(
        `Cannot move stock to a box with status ${targetBox.status}`,
        409,
      );
    }

    if (await stockRepository.existsByBox(targetBox._id)) {
      throw new AppError('Target box already has stock assigned', 409);
    }

    const sourceBox = await boxRepository.findById(currentBoxId);

    const updated = await stockRepository.updateById(stock._id, {
      box: targetBox._id,
      locker: targetLockerId,
    });

    await syncBoxOccupancy(sourceBox, null);
    await syncBoxOccupancy(targetBox, updated);

    await activityService.log({
      action: 'move_stock',
      entity: 'Stock',
      entityId: updated._id,
      adminId,
      metadata: {
        stockId: updated.stockId,
        fromBox: sourceBox?.boxId,
        toBox: targetBox.boxId,
      },
    });

    return formatStock(updated);
  }

  async removeStock(id, adminId) {
    const stock = await stockRepository.findByIdOrStockId(id);
    if (!stock) {
      throw new AppError('Stock not found', 404);
    }

    const boxId = stock.box?._id || stock.box;
    const box = boxId ? await boxRepository.findById(boxId) : null;

    if (box && box.status === 'RESERVED') {
      throw new AppError(
        'Cannot delete: box is reserved. Wait until the reservation is released.',
        409,
      );
    }

    const Order = require('../models/Order');
    const Cart = require('../models/Cart');
    const stockObjectId = stock._id;

    const blockingOrder = await Order.findOne({
      'items.stock': stockObjectId,
      status: {
        $in: [
          'CREATED',
          'WAITING_PAYMENT',
          'PAYMENT_SUCCESS',
          'READY_FOR_COLLECTION',
        ],
      },
    })
      .select('orderNumber status paymentStatus')
      .lean()
      .exec();

    if (blockingOrder) {
      if (
        blockingOrder.paymentStatus === 'SUCCESS' ||
        ['PAYMENT_SUCCESS', 'READY_FOR_COLLECTION'].includes(blockingOrder.status)
      ) {
        throw new AppError(
          `Cannot delete: stock is paid and awaiting collection (order ${blockingOrder.orderNumber}).`,
          409,
        );
      }
      throw new AppError(
        `Cannot delete: stock is part of an active order (${blockingOrder.orderNumber}, ${blockingOrder.status}).`,
        409,
      );
    }

    const blockingCart = await Cart.findOne({
      status: 'ACTIVE',
      'items.stock': stockObjectId,
    })
      .select('cartId')
      .lean()
      .exec();

    if (blockingCart) {
      throw new AppError(
        'Cannot delete: stock is reserved in a customer cart. Clear or checkout the cart first.',
        409,
      );
    }

    await stockRepository.deleteById(stock._id);

    // Free the physical box (EMPTY) so locker matrix + empty-box lists update.
    if (box) {
      await syncBoxOccupancy(box, null);
      if (box.status !== 'MAINTENANCE' && box.status !== 'FAULT') {
        await boxRepository.updateById(box._id, {
          status: 'EMPTY',
          isEmpty: true,
        });
      }
    }

    await activityService.log({
      action: 'remove_stock',
      entity: 'Stock',
      entityId: stock._id,
      adminId,
      metadata: {
        stockId: stock.stockId,
        boxId: box?.boxId,
        itemId: stock.item?.itemId || stock.item,
      },
    });

    return {
      id: stock._id,
      stockId: stock.stockId,
      boxId: box?.boxId || null,
      boxFreed: Boolean(box),
    };
  }
}

module.exports = new StockService();
module.exports.formatStock = formatStock;
module.exports.formatCatalogProduct = formatCatalogProduct;
module.exports.aggregateCatalogByItem = aggregateCatalogByItem;
