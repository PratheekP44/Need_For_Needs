'use strict';

const orderRepository = require('../repositories/order.repository');
const cartRepository = require('../repositories/cart.repository');
const stockRepository = require('../repositories/stock.repository');
const cartService = require('./cart.service');
const activityService = require('./activity.service');
const {
  releaseStockForLines,
} = require('./stockReservation.service');
const AppError = require('../utils/AppError');
const { parseListQuery, buildPagination } = require('../utils/query');
const {
  summarizeLines,
  generateOrderNumber,
} = require('../utils/pricing');
const { formatItem } = require('./item.service');
const inventoryEvents = require('./inventory.events');
const logger = require('../config/logger');
const {
  PENDING_COLLECTION_STATUSES,
  expireOrderIfNeeded,
  isPendingCollection,
} = require('./orderExpiration.service');

function formatNested(doc, fields) {
  if (!doc) return null;
  if (typeof doc !== 'object') return doc;
  const out = { id: doc._id || doc.id };
  fields.forEach((field) => {
    if (doc[field] !== undefined) out[field] = doc[field];
  });
  return out;
}

function formatUser(user) {
  if (!user) return null;
  if (typeof user !== 'object') return user;
  return {
    id: user._id || user.id,
    name: user.name || '',
    email: user.email || '',
    phone: user.phone || '',
  };
}

function formatOrder(order) {
  return {
    id: order._id,
    orderNumber: order.orderNumber,
    user: formatUser(order.user) || order.user,
    locker: formatNested(order.locker, [
      'lockerId',
      'lockerName',
      'status',
      'terminalNumber',
    ]),
    items: (order.items || []).map((line) => ({
      quantity: line.quantity,
      priceAtPurchase: line.priceAtPurchase,
      gstPercentage: line.gstPercentage,
      subtotal: line.subtotal,
      item:
        line.item && typeof line.item === 'object' && line.item.name
          ? formatItem(line.item)
          : line.item,
      stock: formatNested(line.stock, ['stockId', 'currentQuantity', 'status']),
      box: formatNested(line.box, ['boxId', 'boxNumber', 'status']),
      locker: formatNested(line.locker, ['lockerId', 'lockerName']),
    })),
    subtotal: order.subtotal,
    tax: order.tax,
    discount: order.discount,
    grandTotal: order.grandTotal,
    status: order.status,
    paymentStatus: order.paymentStatus,
    paymentId: order.payment || null,
    transactionId: order.transaction || null,
    gatewayPaymentId: order.gatewayPaymentId || '',
    collectionToken: order.collectionToken || '',
    collectionTokenExpiresAt: order.collectionTokenExpiresAt || null,
    stockReserved: order.stockReserved,
    expiresAt: order.expiresAt || null,
    paidAt: order.paidAt || null,
    collectionDeadline: order.collectionDeadline || null,
    cancelledAt: order.cancelledAt || null,
    collectedAt: order.collectedAt || null,
    expiredAt: order.expiredAt || null,
    deletedAt: order.deletedAt || null,
    createdAt: order.createdAt,
    updatedAt: order.updatedAt,
  };
}

function getOrderExpiryMs() {
  const minutes = Number(process.env.ORDER_RESERVATION_MINUTES || 15);
  return Math.max(1, minutes) * 60 * 1000;
}

function assertNotDeleted(order) {
  if (order?.deletedAt) {
    throw new AppError('Order not found', 404);
  }
}

async function releaseReservedStock(order, reason, actorId) {
  if (!order.stockReserved) return;
  await releaseStockForLines(order.items, {
    userId: actorId || order.user,
    orderNumber: order.orderNumber,
    reason,
  });
  inventoryEvents.publish({
    reason:
      reason === 'cancel'
        ? 'order_cancelled'
        : reason === 'expire'
          ? 'order_expired'
          : reason,
    orderNumber: order.orderNumber,
    stockIds: (order.items || [])
      .map((line) => String(line.stock?._id || line.stock || ''))
      .filter(Boolean),
  });
}

class OrderService {
  async checkout(userId, { discount = 0 } = {}) {
    const cart = await cartService.getOrCreateActiveCart(userId);
    if (!cart.items.length) {
      throw new AppError('Cannot checkout an empty cart', 400);
    }

    const lockerIds = new Set(
      cart.items.map((line) => String(line.locker?._id || line.locker)),
    );
    if (lockerIds.size !== 1) {
      throw new AppError('Cart contains items from multiple lockers', 400);
    }

    // Re-validate live stock and item availability
    const orderLines = [];
    for (const line of cart.items) {
      const stock = await stockRepository.findById(line.stock?._id || line.stock);
      const item = stock?.item;
      if (!item || !item.isActive) {
        throw new AppError('Cart contains disabled items', 400);
      }
      if (['DISABLED', 'EXPIRED', 'OUT_OF_STOCK'].includes(stock.status)) {
        throw new AppError('Cart contains unavailable stock', 400);
      }
      if (stock.currentQuantity < line.quantity) {
        throw new AppError(
          `Insufficient stock for ${item.name}. Available: ${stock.currentQuantity}`,
          409,
        );
      }

      orderLines.push({
        item: item._id,
        stock: stock._id,
        locker: stock.locker?._id || stock.locker,
        box: stock.box?._id || stock.box,
        quantity: line.quantity,
        priceAtPurchase: item.sellingPrice,
        gstPercentage: item.gstPercentage || 0,
        subtotal: 0,
      });
    }

    const totals = summarizeLines(orderLines, discount);
    let orderNumber = generateOrderNumber();
    while (await orderRepository.existsByOrderNumber(orderNumber)) {
      orderNumber = generateOrderNumber();
    }

    const expiresAt = new Date(Date.now() + getOrderExpiryMs());
    const lockerId = [...lockerIds][0];

    const order = await orderRepository.create({
      orderNumber,
      user: userId,
      locker: lockerId,
      cart: cart._id,
      items: totals.items,
      subtotal: totals.subtotal,
      tax: totals.tax,
      discount: totals.discount,
      grandTotal: totals.grandTotal,
      status: 'WAITING_PAYMENT',
      paymentStatus: 'PENDING',
      // Inventory is NOT reduced here — only after Razorpay signature verify.
      stockReserved: false,
      expiresAt,
    });

    cart.status = 'CHECKED_OUT';
    cart.items = [];
    cart.subtotal = 0;
    cart.tax = 0;
    cart.discount = 0;
    cart.grandTotal = 0;
    await cartRepository.save(cart);

    // Ensure user has a fresh active cart
    await cartService.getOrCreateActiveCart(userId);

    await activityService.log({
      action: 'checkout',
      entity: 'Order',
      entityId: order._id,
      userId,
      metadata: {
        orderNumber,
        grandTotal: order.grandTotal,
        stockReserved: false,
      },
    });

    return formatOrder(order);
  }

  async listOrders(auth, query) {
    const listQuery = parseListQuery(query, {
      defaultSort: '-createdAt',
      allowedSortFields: [
        'createdAt',
        'updatedAt',
        'grandTotal',
        'status',
        'orderNumber',
        'paidAt',
        'collectionDeadline',
      ],
      filterFields: {
        status: 'status',
        paymentStatus: 'paymentStatus',
        locker: 'locker',
      },
      searchFields: ['orderNumber'],
    });

    if (auth.role !== 'admin') {
      listQuery.filter.user = auth.sub;
    } else if (query.user) {
      listQuery.filter.user = query.user;
    }

    const { items, total } = await orderRepository.list(listQuery);
    return {
      orders: items.map((order) => formatOrder(order)),
      pagination: buildPagination({
        page: listQuery.page,
        limit: listQuery.limit,
        total,
      }),
    };
  }

  async getOrder(auth, id, opts = {}) {
    let order = await orderRepository.findByIdOrOrderNumber(id);
    if (!order) {
      throw new AppError('Order not found', 404);
    }
    assertNotDeleted(order);
    if (auth.role !== 'admin' && String(order.user?._id || order.user) !== String(auth.sub)) {
      throw new AppError('Forbidden', 403);
    }

    order = await expireOrderIfNeeded(order, {
      now: opts.now,
      persist: (oid, data) => orderRepository.updateById(oid, data),
    });

    return formatOrder(order);
  }

  /**
   * Cancel order.
   * - Users: unpaid only (CREATED / WAITING_PAYMENT)
   * - Admin: unpaid OR pending collection (no BLE / no refund automation)
   */
  async cancelOrder(auth, id, { reason } = {}) {
    const order = await orderRepository.findByIdOrOrderNumber(id);
    if (!order) {
      throw new AppError('Order not found', 404);
    }
    assertNotDeleted(order);
    if (auth.role !== 'admin' && String(order.user?._id || order.user) !== String(auth.sub)) {
      throw new AppError('Forbidden', 403);
    }

    const unpaidOk = ['CREATED', 'WAITING_PAYMENT'].includes(order.status);
    const adminPendingOk =
      auth.role === 'admin' && isPendingCollection(order.status);

    if (!unpaidOk && !adminPendingOk) {
      if (auth.role !== 'admin' && isPendingCollection(order.status)) {
        throw new AppError('Unauthorized admin cancellation', 403);
      }
      throw new AppError('Order cannot be cancelled in its current state', 400);
    }

    await releaseReservedStock(order, 'cancel', auth.sub);

    const updated = await orderRepository.updateById(order._id, {
      status: 'CANCELLED',
      cancelledAt: new Date(),
      stockReserved: false,
    });

    await activityService.log({
      action: 'order_cancel',
      entity: 'Order',
      entityId: order._id,
      userId: auth.role === 'user' ? auth.sub : null,
      adminId: auth.role === 'admin' ? auth.sub : null,
      metadata: {
        orderNumber: order.orderNumber,
        reason: reason || null,
        paymentStatus: order.paymentStatus,
        refundNote:
          order.paymentStatus === 'SUCCESS'
            ? 'Cancellation does not auto-refund; handle refund separately'
            : null,
      },
    });

    return formatOrder(updated);
  }

  /**
   * Soft-delete eligible orders (admin only).
   * Eligible: EXPIRED, CANCELLED. Never COLLECTED / pending collection / unpaid active.
   * Does not delete Payment or Transaction documents.
   */
  async deleteOrder(auth, id) {
    if (auth.role !== 'admin') {
      throw new AppError('Unauthorized admin deletion', 403);
    }

    const order = await orderRepository.findByIdOrOrderNumber(id);
    if (!order) {
      throw new AppError('Order not found', 404);
    }
    assertNotDeleted(order);

    if (!['EXPIRED', 'CANCELLED'].includes(order.status)) {
      throw new AppError(
        'Only expired or cancelled orders can be deleted. Prefer cancel for pending collection.',
        400,
      );
    }

    const updated = await orderRepository.updateById(order._id, {
      deletedAt: new Date(),
    });

    await activityService.log({
      action: 'order_delete',
      entity: 'Order',
      entityId: order._id,
      adminId: auth.sub,
      metadata: {
        orderNumber: order.orderNumber,
        status: order.status,
        paymentPreserved: Boolean(order.payment),
        transactionPreserved: Boolean(order.transaction),
      },
    });

    return formatOrder(updated);
  }

  async expireDueOrders(opts = {}) {
    const now = typeof opts.now === 'function' ? opts.now() : opts.now || new Date();
    let count = 0;

    const unpaidDue = await orderRepository.findExpiredPending(now);
    for (const order of unpaidDue) {
      try {
        await releaseReservedStock(order, 'expire', order.user);
        await orderRepository.updateById(order._id, {
          status: 'EXPIRED',
          expiredAt: now,
          stockReserved: false,
        });
        await activityService.log({
          action: 'order_expire',
          entity: 'Order',
          entityId: order._id,
          userId: order.user,
          metadata: {
            orderNumber: order.orderNumber,
            reason: 'unpaid_reservation',
          },
        });
        count += 1;
      } catch (error) {
        logger.error('Failed to expire unpaid order', {
          orderNumber: order.orderNumber,
          message: error.message,
        });
      }
    }

    const collectionDue = await orderRepository.findExpiredCollectionPending(now);
    for (const order of collectionDue) {
      try {
        await expireOrderIfNeeded(order, {
          now: () => now,
          persist: async (oid, data) => {
            await releaseReservedStock(order, 'expire', order.user);
            return orderRepository.updateById(oid, {
              ...data,
              stockReserved: false,
            });
          },
        });
        await activityService.log({
          action: 'order_expire',
          entity: 'Order',
          entityId: order._id,
          userId: order.user,
          metadata: {
            orderNumber: order.orderNumber,
            reason: 'collection_deadline',
            collectionDeadline: order.collectionDeadline,
          },
        });
        count += 1;
      } catch (error) {
        logger.error('Failed to expire collection order', {
          orderNumber: order.orderNumber,
          message: error.message,
        });
      }
    }

    return count;
  }
}

module.exports = new OrderService();
module.exports.formatOrder = formatOrder;
module.exports.PENDING_COLLECTION_STATUSES = PENDING_COLLECTION_STATUSES;
