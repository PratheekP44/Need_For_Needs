'use strict';

const itemRepository = require('../repositories/item.repository');
const stockRepository = require('../repositories/stock.repository');
const activityService = require('./activity.service');
const { getStorage } = require('../storage/storage');
const AppError = require('../utils/AppError');
const { parseListQuery, buildPagination } = require('../utils/query');

const ALLOWED_IMAGE_MIME = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
]);

function mimeFromFilename(name) {
  const lower = String(name || '').toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

function formatItem(item) {
  return typeof item.toPublicObject === 'function'
    ? item.toPublicObject()
    : {
        id: item._id,
        itemId: item.itemId,
        name: item.name,
        description: item.description,
        category: item.category,
        brand: item.brand,
        barcode: item.barcode,
        imageUrl: item.imageUrl,
        sellingPrice: item.sellingPrice,
        costPrice: item.costPrice,
        gstPercentage: item.gstPercentage,
        unit: item.unit,
        isActive: item.isActive,
        tags: item.tags,
        createdBy: item.createdBy,
        updatedBy: item.updatedBy,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      };
}

class ItemService {
  async createItem(payload, adminId) {
    const itemId = String(payload.itemId).trim().toUpperCase();
    const barcode = String(payload.barcode).trim();

    if (await itemRepository.existsByItemId(itemId)) {
      throw new AppError('Item ID already exists', 409);
    }
    if (await itemRepository.existsByBarcode(barcode)) {
      throw new AppError('Barcode already exists', 409);
    }
    if (Number(payload.sellingPrice) < Number(payload.costPrice)) {
      throw new AppError('Selling price must be greater than or equal to cost price', 400);
    }

    const item = await itemRepository.create({
      itemId,
      name: payload.name,
      description: payload.description,
      category: payload.category,
      brand: payload.brand,
      barcode,
      imageUrl: payload.imageUrl || '',
      sellingPrice: payload.sellingPrice,
      costPrice: payload.costPrice,
      gstPercentage: payload.gstPercentage ?? 0,
      unit: payload.unit || 'piece',
      isActive: payload.isActive !== undefined ? payload.isActive : true,
      tags: payload.tags || [],
      createdBy: adminId || null,
      updatedBy: adminId || null,
    });

    await activityService.log({
      action: 'create',
      entity: 'Item',
      entityId: item._id,
      adminId,
      metadata: { itemId: item.itemId },
    });

    return formatItem(item);
  }

  async listItems(query) {
    const listQuery = parseListQuery(query, {
      defaultSort: '-createdAt',
      allowedSortFields: [
        'createdAt',
        'updatedAt',
        'name',
        'sellingPrice',
        'costPrice',
        'brand',
        'category',
      ],
      filterFields: {
        category: 'category',
        brand: 'brand',
        barcode: 'barcode',
        isActive: 'isActive',
        itemId: 'itemId',
      },
      searchFields: ['name', 'brand', 'barcode', 'itemId', 'description', 'category'],
    });

    if (query.minPrice !== undefined || query.maxPrice !== undefined) {
      listQuery.filter.sellingPrice = {};
      if (query.minPrice !== undefined && query.minPrice !== '') {
        listQuery.filter.sellingPrice.$gte = Number(query.minPrice);
      }
      if (query.maxPrice !== undefined && query.maxPrice !== '') {
        listQuery.filter.sellingPrice.$lte = Number(query.maxPrice);
      }
    }

    if (listQuery.filter.isActive !== undefined) {
      const value = String(listQuery.filter.isActive).toLowerCase();
      listQuery.filter.isActive = value === 'true' || value === '1';
    }

    if (listQuery.filter.itemId) {
      listQuery.filter.itemId = String(listQuery.filter.itemId).toUpperCase();
    }

    // Convenience aliases for sorting
    if (query.sort === 'newest') listQuery.sort = '-createdAt';
    if (query.sort === 'oldest') listQuery.sort = 'createdAt';
    if (query.sort === 'price') listQuery.sort = 'sellingPrice';
    if (query.sort === '-price') listQuery.sort = '-sellingPrice';
    if (query.sort === 'name') listQuery.sort = 'name';

    const { items, total } = await itemRepository.list(listQuery);

    return {
      items: items.map((item) => formatItem(item)),
      pagination: buildPagination({
        page: listQuery.page,
        limit: listQuery.limit,
        total,
      }),
    };
  }

  async getItemById(id) {
    const item = await itemRepository.findByIdOrItemId(id);
    if (!item) {
      throw new AppError('Item not found', 404);
    }
    return formatItem(item);
  }

  async updateItem(id, payload, adminId) {
    const item = await itemRepository.findByIdOrItemId(id);
    if (!item) {
      throw new AppError('Item not found', 404);
    }

    const updates = { ...payload, updatedBy: adminId || null };

    if (updates.itemId) {
      updates.itemId = String(updates.itemId).trim().toUpperCase();
      if (
        updates.itemId !== item.itemId &&
        (await itemRepository.existsByItemId(updates.itemId, item._id))
      ) {
        throw new AppError('Item ID already exists', 409);
      }
    }

    if (updates.barcode) {
      updates.barcode = String(updates.barcode).trim();
      if (
        updates.barcode !== item.barcode &&
        (await itemRepository.existsByBarcode(updates.barcode, item._id))
      ) {
        throw new AppError('Barcode already exists', 409);
      }
    }

    const nextSelling =
      updates.sellingPrice !== undefined ? updates.sellingPrice : item.sellingPrice;
    const nextCost =
      updates.costPrice !== undefined ? updates.costPrice : item.costPrice;
    if (Number(nextSelling) < Number(nextCost)) {
      throw new AppError('Selling price must be greater than or equal to cost price', 400);
    }

    const updated = await itemRepository.updateById(item._id, updates);
    await activityService.log({
      action: 'update',
      entity: 'Item',
      entityId: updated._id,
      adminId,
      metadata: { itemId: updated.itemId },
    });

    return formatItem(updated);
  }

  async deleteItem(id, adminId) {
    const item = await itemRepository.findByIdOrItemId(id);
    if (!item) {
      throw new AppError('Item not found', 404);
    }

    const linkedStock = await stockRepository.countByItem(item._id);
    if (linkedStock > 0) {
      throw new AppError(
        'Cannot delete this item because it is currently assigned to inventory',
        409,
      );
    }

    const Cart = require('../models/Cart');
    const activeCart = await Cart.findOne({
      'items.item': item._id,
      status: 'ACTIVE',
    })
      .select('_id')
      .lean()
      .exec();
    if (activeCart) {
      throw new AppError(
        'Cannot delete this item because it is in one or more active carts',
        409,
      );
    }

    const Order = require('../models/Order');
    const blockingOrder = await Order.findOne({
      'items.item': item._id,
      status: {
        $in: [
          'CREATED',
          'WAITING_PAYMENT',
          'PAYMENT_SUCCESS',
          'READY_FOR_COLLECTION',
        ],
      },
    })
      .select('orderNumber status')
      .lean()
      .exec();
    if (blockingOrder) {
      throw new AppError(
        `Cannot delete this item because it is referenced by active order ${blockingOrder.orderNumber}`,
        409,
      );
    }

    await itemRepository.deleteById(item._id);
    await activityService.log({
      action: 'delete',
      entity: 'Item',
      entityId: item._id,
      adminId,
      metadata: { itemId: item.itemId },
    });

    return { id: item._id, itemId: item.itemId };
  }

  async uploadImage(id, file, adminId) {
    if (!file || !file.buffer) {
      throw new AppError('Image file is required', 400);
    }
    if (!Buffer.isBuffer(file.buffer) || file.buffer.length === 0) {
      throw new AppError('Image file is empty', 400);
    }

    const item = await itemRepository.findByIdOrItemId(id);
    if (!item) {
      throw new AppError('Item not found', 404);
    }

    const storage = getStorage();
    const originalName = file.originalname || 'product.jpg';
    const mimeType =
      file.mimetype && ALLOWED_IMAGE_MIME.has(file.mimetype)
        ? file.mimetype
        : mimeFromFilename(originalName);

    const saved = await storage.save({
      buffer: file.buffer,
      originalName,
      mimeType,
      folder: 'items',
    });

    const previous = item.imageUrl;
    const updated = await itemRepository.updateById(item._id, {
      imageUrl: saved.publicUrl,
      updatedBy: adminId || null,
    });

    if (previous && previous !== saved.publicUrl) {
      try {
        await storage.delete(previous);
      } catch (_) {
        // Best-effort cleanup of prior local file.
      }
    }

    await activityService.log({
      action: 'upload_image',
      entity: 'Item',
      entityId: updated._id,
      adminId,
      metadata: { itemId: updated.itemId, imageUrl: saved.publicUrl },
    });

    return formatItem(updated);
  }

  async removeImage(id, adminId) {
    const item = await itemRepository.findByIdOrItemId(id);
    if (!item) {
      throw new AppError('Item not found', 404);
    }

    const previous = item.imageUrl;
    const updated = await itemRepository.updateById(item._id, {
      imageUrl: '',
      updatedBy: adminId || null,
    });

    if (previous) {
      try {
        await getStorage().delete(previous);
      } catch (_) {
        // Best-effort cleanup.
      }
    }

    await activityService.log({
      action: 'remove_image',
      entity: 'Item',
      entityId: updated._id,
      adminId,
      metadata: { itemId: updated.itemId },
    });

    return formatItem(updated);
  }
}

module.exports = new ItemService();
module.exports.formatItem = formatItem;
