'use strict';

const cartRepository = require('../repositories/cart.repository');
const stockRepository = require('../repositories/stock.repository');
const itemRepository = require('../repositories/item.repository');
const activityService = require('./activity.service');
const AppError = require('../utils/AppError');
const {
  summarizeLines,
  generateCartId,
  lineSubtotal,
} = require('../utils/pricing');
const { formatItem } = require('./item.service');

function formatNested(doc, fields) {
  if (!doc) return null;
  if (typeof doc !== 'object') return doc;
  const out = { id: doc._id || doc.id };
  fields.forEach((field) => {
    if (doc[field] !== undefined) out[field] = doc[field];
  });
  return out;
}

function formatCart(cart) {
  return {
    id: cart._id,
    cartId: cart.cartId,
    user: cart.user,
    status: cart.status,
    subtotal: cart.subtotal,
    discount: cart.discount,
    tax: cart.tax,
    grandTotal: cart.grandTotal,
    items: (cart.items || []).map((line) => ({
      id: line._id,
      quantity: line.quantity,
      priceAtPurchase: line.priceAtPurchase,
      gstPercentage: line.gstPercentage,
      subtotal: line.subtotal,
      item:
        line.item && typeof line.item === 'object' && line.item.name
          ? formatItem(line.item)
          : line.item,
      stock: formatNested(line.stock, [
        'stockId',
        'currentQuantity',
        'status',
        'maximumQuantity',
      ]),
      locker: formatNested(line.locker, ['lockerId', 'lockerName', 'status']),
      box: formatNested(line.box, ['boxId', 'boxNumber', 'status', 'isEmpty']),
    })),
    createdAt: cart.createdAt,
    updatedAt: cart.updatedAt,
  };
}

function assertStockSellable(stock, item, quantity) {
  if (!stock) {
    throw new AppError('Stock not found', 404);
  }
  if (!item || !item.isActive) {
    throw new AppError('Cannot order disabled or missing items', 400);
  }
  if (['DISABLED', 'EXPIRED', 'OUT_OF_STOCK'].includes(stock.status)) {
    throw new AppError('Stock is unavailable for purchase', 400);
  }
  if (stock.currentQuantity < quantity) {
    throw new AppError(
      `Insufficient stock. Available: ${stock.currentQuantity}`,
      409,
    );
  }
}

function isBlankId(value) {
  if (value === null || value === undefined) return true;
  const text = String(value).trim();
  return !text || text === 'null' || text === 'undefined';
}

function resolveMongoId(ref) {
  if (!ref) return null;
  if (typeof ref === 'object') {
    const id = ref._id || ref.id;
    return id ? String(id) : null;
  }
  const text = String(ref).trim();
  if (isBlankId(text)) return null;
  return text;
}

function clientMatchesRef(clientValue, populatedRef, businessField) {
  if (isBlankId(clientValue) || !populatedRef) return false;
  const client = String(clientValue).trim();
  const mongoId = resolveMongoId(populatedRef);
  if (mongoId && client === mongoId) return true;
  if (typeof populatedRef === 'object' && populatedRef[businessField]) {
    return (
      client.toUpperCase() === String(populatedRef[businessField]).toUpperCase()
    );
  }
  return false;
}

class CartService {
  async getOrCreateActiveCart(userId) {
    let cart = await cartRepository.findActiveByUser(userId);
    if (cart) {
      return cart;
    }

    cart = await cartRepository.create({
      cartId: generateCartId(userId),
      user: userId,
      items: [],
      subtotal: 0,
      discount: 0,
      tax: 0,
      grandTotal: 0,
      status: 'ACTIVE',
    });

    return cartRepository.findById(cart._id);
  }

  async getCart(userId) {
    const cart = await this.getOrCreateActiveCart(userId);
    return formatCart(cart);
  }

  async addItem(userId, payload = {}) {
    const qty = Number(payload.quantity);
    if (!Number.isInteger(qty) || qty < 1) {
      throw new AppError('Quantity must be a positive integer', 400);
    }

    const itemRef = payload.itemId || payload.item;
    if (itemRef) {
      return this.addItemByProduct(userId, {
        itemRef,
        preferredLockerId: payload.lockerId,
        quantity: qty,
      });
    }

    return this.addItemByStock(userId, {
      stockId: payload.stockId,
      lockerId: payload.lockerId,
      boxId: payload.boxId,
      quantity: qty,
    });
  }

  /**
   * Customer catalog path: allocate distinct sellable stock rows for the product
   * and bind each to the cart (one physical box per unit).
   */
  async addItemByProduct(userId, { itemRef, preferredLockerId, quantity }) {
    const item = await itemRepository.findByIdOrItemId(itemRef);
    if (!item || !item.isActive) {
      throw new AppError('Product not found', 404);
    }

    const cart = await this.getOrCreateActiveCart(userId);
    const cartLockerId =
      cart.items.length > 0 ? resolveMongoId(cart.items[0].locker) : null;

    let lockerFilter = null;
    if (cartLockerId) {
      lockerFilter = cartLockerId;
    } else if (!isBlankId(preferredLockerId)) {
      lockerFilter = preferredLockerId;
    }

    const excludeIds = cart.items
      .map((line) => resolveMongoId(line.stock))
      .filter(Boolean);

    let units = await stockRepository.findSellableByItem(item._id, {
      lockerId: lockerFilter,
      excludeIds,
      limit: quantity,
    });

    if (units.length < quantity && !cartLockerId && lockerFilter) {
      units = await stockRepository.findSellableByItem(item._id, {
        lockerId: null,
        excludeIds,
        limit: quantity,
      });
    }

    if (units.length < quantity) {
      throw new AppError(
        `Insufficient stock. Available: ${units.length}`,
        409,
      );
    }

    const lockerIds = new Set(
      units.map((u) => resolveMongoId(u.locker)).filter(Boolean),
    );
    if (lockerIds.size > 1) {
      const primaryLocker = resolveMongoId(units[0].locker);
      units = units.filter((u) => resolveMongoId(u.locker) === primaryLocker);
      if (units.length < quantity) {
        throw new AppError(
          `Insufficient stock at one locker. Available: ${units.length}`,
          409,
        );
      }
    }

    if (cartLockerId) {
      const allocatedLocker = resolveMongoId(units[0].locker);
      if (allocatedLocker !== cartLockerId) {
        throw new AppError('Cart can only contain items from one locker', 400);
      }
    }

    const allocated = units.slice(0, quantity);
    for (const stock of allocated) {
      this.pushCartLine(cart, stock, 1);
    }

    const totals = summarizeLines(cart.items, cart.discount);
    cart.subtotal = totals.subtotal;
    cart.tax = totals.tax;
    cart.grandTotal = totals.grandTotal;
    await cartRepository.save(cart);

    await activityService.log({
      action: 'cart_add',
      entity: 'Cart',
      entityId: cart._id,
      userId,
      metadata: {
        itemId: item.itemId,
        quantity,
        allocatedStockIds: allocated.map((u) => u.stockId),
        allocatedBoxes: allocated.map((u) => u.box?.boxId || u.box?._id),
      },
    });

    return formatCart(await cartRepository.findById(cart._id));
  }

  pushCartLine(cart, stock, qty) {
    const item = stock.item;
    assertStockSellable(stock, item, qty);

    const resolvedLockerId = resolveMongoId(stock.locker);
    const resolvedBoxId = resolveMongoId(stock.box);
    const itemId = resolveMongoId(item);
    const resolvedStockId = resolveMongoId(stock);

    if (!resolvedLockerId || !resolvedBoxId || !itemId || !resolvedStockId) {
      throw new AppError('Stock mapping is incomplete', 409);
    }

    const existing = cart.items.find(
      (line) => resolveMongoId(line.stock) === resolvedStockId,
    );

    if (existing) {
      const nextQty = existing.quantity + qty;
      assertStockSellable(stock, item, nextQty);
      existing.quantity = nextQty;
      existing.priceAtPurchase = item.sellingPrice;
      existing.gstPercentage = item.gstPercentage || 0;
      existing.subtotal = lineSubtotal(nextQty, existing.priceAtPurchase);
    } else {
      cart.items.push({
        item: itemId,
        stock: resolvedStockId,
        locker: resolvedLockerId,
        box: resolvedBoxId,
        quantity: qty,
        priceAtPurchase: item.sellingPrice,
        gstPercentage: item.gstPercentage || 0,
        subtotal: lineSubtotal(qty, item.sellingPrice),
      });
    }
  }

  async addItemByStock(userId, { stockId, lockerId, boxId, quantity }) {
    const qty = Number(quantity);
    if (!Number.isInteger(qty) || qty < 1) {
      throw new AppError('Quantity must be a positive integer', 400);
    }

    if (isBlankId(stockId)) {
      throw new AppError('stockId is required', 400);
    }
    if (isBlankId(lockerId) || isBlankId(boxId)) {
      throw new AppError('lockerId and boxId are required and cannot be null', 400);
    }

    const stock = await stockRepository.findByIdOrStockId(stockId);
    if (!stock) {
      throw new AppError('Stock not found', 404);
    }

    if (!stock.locker || !stock.box) {
      throw new AppError(
        'Stock is missing locker/box assignment. Re-assign stock in admin before adding to cart.',
        409,
      );
    }

    if (!clientMatchesRef(lockerId, stock.locker, 'lockerId')) {
      throw new AppError('lockerId does not match the stock locker', 400);
    }
    if (!clientMatchesRef(boxId, stock.box, 'boxId')) {
      throw new AppError('boxId does not match the stock box', 400);
    }

    const cart = await this.getOrCreateActiveCart(userId);
    const resolvedLockerId = resolveMongoId(stock.locker);

    if (cart.items.length > 0) {
      const existingLocker = resolveMongoId(cart.items[0].locker);
      if (existingLocker !== resolvedLockerId) {
        throw new AppError(
          'Cart can only contain items from one locker',
          400,
        );
      }
    }

    this.pushCartLine(cart, stock, qty);

    const totals = summarizeLines(cart.items, cart.discount);
    cart.subtotal = totals.subtotal;
    cart.tax = totals.tax;
    cart.grandTotal = totals.grandTotal;
    await cartRepository.save(cart);

    await activityService.log({
      action: 'cart_add',
      entity: 'Cart',
      entityId: cart._id,
      userId,
      metadata: { stockId: stock.stockId, quantity: qty },
    });

    const fresh = await cartRepository.findById(cart._id);
    return formatCart(fresh);
  }

  async updateItem(userId, { cartItemId, quantity }) {
    const qty = Number(quantity);
    if (!Number.isInteger(qty) || qty < 1) {
      throw new AppError('Quantity must be a positive integer', 400);
    }

    const cart = await this.getOrCreateActiveCart(userId);
    const line = cart.items.id(cartItemId);
    if (!line) {
      throw new AppError('Cart item not found', 404);
    }

    const stock = await stockRepository.findById(line.stock?._id || line.stock);
    const item = stock?.item;
    assertStockSellable(stock, item, qty);

    line.quantity = qty;
    line.priceAtPurchase = item.sellingPrice;
    line.gstPercentage = item.gstPercentage || 0;
    line.subtotal = lineSubtotal(qty, line.priceAtPurchase);

    const totals = summarizeLines(cart.items, cart.discount);
    cart.subtotal = totals.subtotal;
    cart.tax = totals.tax;
    cart.grandTotal = totals.grandTotal;
    await cartRepository.save(cart);

    await activityService.log({
      action: 'cart_update',
      entity: 'Cart',
      entityId: cart._id,
      userId,
      metadata: { cartItemId, quantity: qty },
    });

    const fresh = await cartRepository.findById(cart._id);
    return formatCart(fresh);
  }

  async removeItem(userId, cartItemId) {
    const cart = await this.getOrCreateActiveCart(userId);
    const line = cart.items.id(cartItemId);
    if (!line) {
      throw new AppError('Cart item not found', 404);
    }

    line.deleteOne();
    const totals = summarizeLines(cart.items, cart.discount);
    cart.subtotal = totals.subtotal;
    cart.tax = totals.tax;
    cart.grandTotal = totals.grandTotal;
    await cartRepository.save(cart);

    await activityService.log({
      action: 'cart_remove',
      entity: 'Cart',
      entityId: cart._id,
      userId,
      metadata: { cartItemId },
    });

    const fresh = await cartRepository.findById(cart._id);
    return formatCart(fresh);
  }

  async clearCart(userId) {
    const cart = await this.getOrCreateActiveCart(userId);
    cart.items = [];
    cart.subtotal = 0;
    cart.tax = 0;
    cart.discount = 0;
    cart.grandTotal = 0;
    await cartRepository.save(cart);

    await activityService.log({
      action: 'cart_clear',
      entity: 'Cart',
      entityId: cart._id,
      userId,
    });

    const fresh = await cartRepository.findById(cart._id);
    return formatCart(fresh);
  }

  async markCheckedOut(cart) {
    cart.status = 'CHECKED_OUT';
    await cartRepository.save(cart);
  }
}

module.exports = new CartService();
module.exports.formatCart = formatCart;
