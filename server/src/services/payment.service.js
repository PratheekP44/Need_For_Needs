'use strict';

const paymentRepository = require('../repositories/payment.repository');
const orderRepository = require('../repositories/order.repository');
const transactionRepository = require('../repositories/transaction.repository');
const activityService = require('./activity.service');
const inventoryEvents = require('./inventory.events');
const { reserveStockForLines, releaseStockForLines } = require('./stockReservation.service');
const {
  createRazorpayOrder,
  verifyPaymentSignature,
  toPaise,
  getCredentials,
} = require('./razorpay.client');
const AppError = require('../utils/AppError');
const { parseListQuery, buildPagination } = require('../utils/query');
const { formatOrder } = require('./order.service');
const logger = require('../config/logger');

function formatPayment(payment) {
  if (!payment) return null;
  const order = payment.order;
  return {
    id: payment._id,
    order:
      order && typeof order === 'object' && order.orderNumber
        ? {
            id: order._id,
            orderNumber: order.orderNumber,
            status: order.status,
            paymentStatus: order.paymentStatus,
            grandTotal: order.grandTotal,
          }
        : payment.order,
    user: payment.user,
    gateway: payment.gateway,
    gatewayOrderId: payment.gatewayOrderId,
    gatewayPaymentId: payment.gatewayPaymentId,
    signature: payment.signature,
    currency: payment.currency,
    amount: payment.amount,
    paymentMethod: payment.paymentMethod,
    isMock: false,
    status: payment.status,
    failureReason: payment.failureReason,
    refundNote: payment.refundNote,
    verifiedAt: payment.verifiedAt,
    failedAt: payment.failedAt,
    refundedAt: payment.refundedAt,
    createdAt: payment.createdAt,
    updatedAt: payment.updatedAt,
  };
}

function stockIdsFromOrder(order) {
  return (order.items || [])
    .map((line) => String(line.stock?._id || line.stock || ''))
    .filter(Boolean);
}

function resolveCollectionParts(orderDoc) {
  const lockerId =
    orderDoc.locker?.lockerId ||
    orderDoc.items?.[0]?.locker?.lockerId ||
    'LOCKER';
  const firstBox = orderDoc.items?.[0]?.box;
  const boxId =
    (firstBox && (firstBox.boxNumber || firstBox.boxId)) ||
    'BOX';
  return { lockerId: String(lockerId), boxId: String(boxId) };
}

/**
 * Owner id whether `user` is a raw ObjectId or a populated User doc.
 * Matches order.service / collectUnlock / unlockPayload convention.
 */
function ownerUserId(userRef) {
  return String(userRef?._id || userRef || '');
}

function assertOwnedByAuth(auth, userRef) {
  if (auth.role === 'admin') return;
  if (ownerUserId(userRef) !== String(auth.sub)) {
    throw new AppError('Forbidden', 403);
  }
}

class PaymentService {
  /**
   * Creates a Razorpay TEST MODE order for an unpaid Campus Essentials order.
   * Does not reduce inventory.
   */
  async createOrder(auth, { orderId }) {
    const order = await orderRepository.findByIdOrOrderNumber(orderId);
    if (!order) {
      throw new AppError('Order not found', 404);
    }
    assertOwnedByAuth(auth, order.user);

    if (order.status === 'EXPIRED' || order.status === 'CANCELLED') {
      throw new AppError('Order is no longer payable', 400);
    }
    if (
      order.status === 'PAYMENT_SUCCESS' ||
      order.status === 'READY_FOR_COLLECTION' ||
      order.status === 'COLLECTED'
    ) {
      throw new AppError('Order is already paid', 409);
    }
    if (order.paymentStatus === 'SUCCESS') {
      throw new AppError('Order payment already completed', 409);
    }
    if (order.status !== 'WAITING_PAYMENT' && order.status !== 'CREATED') {
      throw new AppError(`Order status ${order.status} cannot accept payment`, 400);
    }
    if (order.expiresAt && new Date(order.expiresAt) <= new Date()) {
      throw new AppError('Order reservation has expired', 400);
    }

    const existingSuccess = await paymentRepository.findSuccessfulByOrderId(order._id);
    if (existingSuccess) {
      throw new AppError('Duplicate payment: order already has a successful payment', 409);
    }

    const amount = Number(order.grandTotal);
    if (!(amount > 0)) {
      throw new AppError('Order grand total must be greater than zero', 400);
    }

    // Reuse a PENDING payment row if the client retries create-order for the same unpaid order.
    const latest = await paymentRepository.findLatestByOrderId(order._id);
    if (latest && latest.status === 'PENDING' && latest.gatewayOrderId) {
      const amountPaise = toPaise(amount);
      const { keyId } = getCredentials();
      if (!keyId) {
        throw new AppError(
          'Razorpay TEST MODE is not configured. Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET',
          503,
        );
      }
      return {
        payment: formatPayment(latest),
        razorpay: {
          keyId,
          orderId: latest.gatewayOrderId,
          amount: amountPaise,
          currency: latest.currency || 'INR',
          name: 'Campus Essentials',
          description: `Order ${order.orderNumber}`,
          receipt: order.orderNumber,
          mock: false,
        },
        order: formatOrder(order),
      };
    }

    const amountPaise = toPaise(amount);
    const { razorpayOrder, keyId } = await createRazorpayOrder({
      amountPaise,
      currency: 'INR',
      receipt: order.orderNumber,
      notes: {
        orderId: String(order._id),
        orderNumber: order.orderNumber,
      },
    });

    const payment = await paymentRepository.create({
      order: order._id,
      user: order.user,
      gateway: 'razorpay',
      gatewayOrderId: razorpayOrder.id,
      gatewayPaymentId: null,
      signature: null,
      currency: razorpayOrder.currency || 'INR',
      amount,
      paymentMethod: null,
      isMock: false,
      status: 'PENDING',
    });

    await transactionRepository.create({
      user: order.user,
      order: order._id,
      payment: payment._id,
      amount,
      status: 'initiated',
    });

    await activityService.log({
      action: 'payment_created',
      entity: 'Payment',
      entityId: payment._id,
      userId: auth.role === 'user' ? auth.sub : null,
      adminId: auth.role === 'admin' ? auth.sub : null,
      metadata: {
        orderNumber: order.orderNumber,
        gatewayOrderId: razorpayOrder.id,
        amount,
        mode: 'test',
      },
    });

    return {
      payment: formatPayment(payment),
      razorpay: {
        keyId,
        orderId: razorpayOrder.id,
        amount: amountPaise,
        currency: razorpayOrder.currency || 'INR',
        name: 'Campus Essentials',
        description: `Order ${order.orderNumber}`,
        receipt: order.orderNumber,
        mock: false,
      },
      order: formatOrder(order),
    };
  }

  /**
   * Verifies Razorpay signature, assigns ONE physical stock record per line,
   * issues collection token, writes Transaction, broadcasts inventory.
   */
  async verify(auth, payload) {
    const {
      razorpay_order_id: razorpayOrderId,
      razorpay_payment_id: razorpayPaymentId,
      razorpay_signature: razorpaySignature,
      paymentMethod = 'razorpay',
    } = payload || {};

    if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      throw new AppError(
        'razorpay_order_id, razorpay_payment_id and razorpay_signature are required',
        400,
      );
    }

    const payment = await paymentRepository.findByGatewayOrderId(razorpayOrderId);
    if (!payment) {
      throw new AppError('Invalid Razorpay order ID', 404);
    }

    let orderDoc = await orderRepository.findById(payment.order?._id || payment.order);
    if (!orderDoc) {
      throw new AppError('Order not found for payment', 404);
    }

    assertOwnedByAuth(auth, orderDoc.user);

    // Idempotent success — safe for client retries after a network blip.
    if (payment.status === 'SUCCESS' && orderDoc.paymentStatus === 'SUCCESS') {
      return {
        payment: formatPayment(payment),
        order: formatOrder(orderDoc),
        idempotent: true,
      };
    }

    if (payment.status === 'REFUNDED') {
      throw new AppError('Payment was refunded and cannot be verified', 400);
    }

    if (payment.status === 'FAILED' && payment.gatewayPaymentId) {
      throw new AppError(
        'Payment already marked failed — create a new payment order to retry',
        400,
      );
    }

    const existingCapture = await paymentRepository.findSuccessfulByGatewayPaymentId(
      razorpayPaymentId,
    );
    if (existingCapture && String(existingCapture._id) !== String(payment._id)) {
      throw new AppError('Duplicate payment verification rejected', 409);
    }

    const valid = verifyPaymentSignature({
      razorpayOrderId,
      razorpayPaymentId,
      razorpaySignature,
    });

    if (!valid) {
      await paymentRepository.updateById(payment._id, {
        status: 'FAILED',
        failureReason: `Invalid Razorpay signature (attemptedPaymentId=${razorpayPaymentId})`,
        failedAt: new Date(),
        signature: razorpaySignature,
      });

      const tx = await transactionRepository.findByPaymentId(payment._id);
      if (tx && tx.status === 'initiated') {
        await transactionRepository.updateById(tx._id, { status: 'failed' });
      }

      await activityService.log({
        action: 'payment_failed',
        entity: 'Payment',
        entityId: payment._id,
        userId: auth.role === 'user' ? auth.sub : null,
        adminId: auth.role === 'admin' ? auth.sub : null,
        metadata: {
          orderNumber: orderDoc.orderNumber,
          reason: 'invalid_signature',
          attemptedPaymentId: razorpayPaymentId,
        },
      });

      throw new AppError('Invalid payment signature', 400);
    }

    // Signature OK — mark payment success first (money is captured).
    const updatedPayment = await paymentRepository.updateById(payment._id, {
      status: 'SUCCESS',
      gatewayPaymentId: razorpayPaymentId,
      signature: razorpaySignature,
      paymentMethod: paymentMethod || 'razorpay',
      isMock: false,
      verifiedAt: new Date(),
      failureReason: null,
      failedAt: null,
    });

    // Assign physical stock AFTER payment — one stock record per order line.
    if (!orderDoc.stockReserved) {
      try {
        await reserveStockForLines(orderDoc.items, {
          userId: auth.role === 'user' ? auth.sub : orderDoc.user,
          orderNumber: orderDoc.orderNumber,
        });
      } catch (error) {
        logger.error('Stock assignment failed after paid verify', {
          orderNumber: orderDoc.orderNumber,
          gatewayPaymentId: razorpayPaymentId,
          message: error.message,
        });
        await activityService.log({
          action: 'stock_assign_failed',
          entity: 'Order',
          entityId: orderDoc._id,
          userId: auth.role === 'user' ? auth.sub : null,
          adminId: auth.role === 'admin' ? auth.sub : null,
          metadata: {
            orderNumber: orderDoc.orderNumber,
            gatewayPaymentId: razorpayPaymentId,
            reason: error.message,
          },
        });
        throw new AppError(
          `Payment captured but stock assignment failed: ${error.message}. Contact support with payment id ${razorpayPaymentId}`,
          409,
        );
      }
    }

    const { issueCollectionToken } = require('./admin.service');
    const parts = resolveCollectionParts(orderDoc);
    const token = issueCollectionToken({
      orderNumber: orderDoc.orderNumber,
      lockerId: parts.lockerId,
      boxId: parts.boxId,
      ttlSeconds: 24 * 60 * 60,
    });
    const tokenExpiry = new Date(Date.now() + 24 * 60 * 60 * 1000);

    let tx = await transactionRepository.findByPaymentId(payment._id);
    if (!tx) {
      tx = await transactionRepository.create({
        user: orderDoc.user,
        order: orderDoc._id,
        payment: payment._id,
        amount: payment.amount,
        status: 'success',
      });
    } else {
      tx = await transactionRepository.updateById(tx._id, { status: 'success' });
    }

    // Phase 23 — collection window starts at successful payment verification (server UTC).
    const {
      computeCollectionDeadline,
    } = require('./orderExpiration.service');
    const paidAt = new Date();
    const collectionDeadline = computeCollectionDeadline(paidAt);

    const updatedOrder = await orderRepository.updateById(orderDoc._id, {
      status: 'READY_FOR_COLLECTION',
      paymentStatus: 'SUCCESS',
      stockReserved: true,
      payment: payment._id,
      transaction: tx._id,
      gatewayPaymentId: razorpayPaymentId,
      collectionToken: token,
      collectionTokenExpiresAt: tokenExpiry,
      paidAt,
      collectionDeadline,
    });

    inventoryEvents.publish({
      reason: 'payment_verified',
      orderNumber: orderDoc.orderNumber,
      stockIds: stockIdsFromOrder(orderDoc),
    });

    await activityService.log({
      action: 'payment_verified',
      entity: 'Payment',
      entityId: payment._id,
      userId: auth.role === 'user' ? auth.sub : null,
      adminId: auth.role === 'admin' ? auth.sub : null,
      metadata: {
        orderNumber: orderDoc.orderNumber,
        gatewayPaymentId: razorpayPaymentId,
        transactionId: String(tx._id),
        orderStatus: 'READY_FOR_COLLECTION',
        paymentStatus: 'SUCCESS',
        collectionTokenIssued: true,
      },
    });

    return {
      payment: formatPayment(updatedPayment),
      order: formatOrder(updatedOrder),
    };
  }

  /**
   * Marks payment failed. Releases stock only if it was already assigned.
   */
  async fail(auth, { orderId, reason = 'Payment failed at gateway' }) {
    const order = await orderRepository.findByIdOrOrderNumber(orderId);
    if (!order) {
      throw new AppError('Order not found', 404);
    }
    assertOwnedByAuth(auth, order.user);
    if (order.paymentStatus === 'SUCCESS') {
      throw new AppError('Cannot fail a successful payment', 400);
    }
    if (['CANCELLED', 'EXPIRED', 'COLLECTED'].includes(order.status)) {
      throw new AppError(`Order status ${order.status} cannot be marked failed`, 400);
    }

    let payment = await paymentRepository.findLatestByOrderId(order._id);
    if (payment && payment.status === 'SUCCESS') {
      throw new AppError('Cannot fail a successful payment', 400);
    }

    if (payment && ['CREATED', 'PENDING'].includes(payment.status)) {
      payment = await paymentRepository.updateById(payment._id, {
        status: 'FAILED',
        failureReason: reason,
        failedAt: new Date(),
      });
      const tx = await transactionRepository.findByPaymentId(payment._id);
      if (tx && tx.status === 'initiated') {
        await transactionRepository.updateById(tx._id, { status: 'failed' });
      }
    } else if (!payment) {
      // No create-order yet — record a terminal FAILED row with a unique
      // synthetic gateway id so sparse/unique indexes stay happy.
      payment = await paymentRepository.create({
        order: order._id,
        user: order.user,
        gateway: 'razorpay',
        gatewayOrderId: `local_fail_${order._id}_${Date.now()}`,
        amount: order.grandTotal,
        currency: 'INR',
        status: 'FAILED',
        isMock: false,
        failureReason: reason,
        failedAt: new Date(),
      });
    }

    const updatedOrder = await this.#markOrderFailedAndRelease(order, auth, reason);

    await activityService.log({
      action: 'payment_failed',
      entity: 'Payment',
      entityId: payment._id,
      userId: auth.role === 'user' ? auth.sub : null,
      adminId: auth.role === 'admin' ? auth.sub : null,
      metadata: {
        orderNumber: order.orderNumber,
        reason,
      },
    });

    return {
      payment: formatPayment(payment),
      order: formatOrder(updatedOrder),
    };
  }

  async refundPlaceholder(auth, paymentId, { note = 'Refund placeholder — not processed at gateway' } = {}) {
    if (auth.role !== 'admin') {
      throw new AppError('Only admins can initiate refund placeholders', 403);
    }

    const payment = await paymentRepository.findById(paymentId);
    if (!payment) {
      throw new AppError('Payment not found', 404);
    }
    if (payment.status !== 'SUCCESS') {
      throw new AppError('Only successful payments can be refunded', 400);
    }

    const updatedPayment = await paymentRepository.updateById(payment._id, {
      status: 'REFUNDED',
      refundNote: note,
      refundedAt: new Date(),
    });

    const orderId = payment.order?._id || payment.order;
    if (orderId) {
      await orderRepository.updateById(orderId, {
        paymentStatus: 'REFUNDED',
      });
    }

    const tx = await transactionRepository.findByPaymentId(payment._id);
    if (tx) {
      await transactionRepository.updateById(tx._id, { status: 'reversed' });
    }

    await activityService.log({
      action: 'payment_refunded',
      entity: 'Payment',
      entityId: payment._id,
      adminId: auth.sub,
      metadata: {
        note,
        placeholder: true,
        gatewayOrderId: payment.gatewayOrderId,
      },
    });

    return {
      payment: formatPayment(updatedPayment),
      message: 'Refund placeholder recorded. No gateway refund was executed.',
    };
  }

  async getById(auth, id) {
    const payment = await paymentRepository.findById(id);
    if (!payment) {
      throw new AppError('Payment not found', 404);
    }
    assertOwnedByAuth(auth, payment.user);
    return formatPayment(payment);
  }

  async list(auth, query) {
    const listQuery = parseListQuery(query, {
      defaultSort: '-createdAt',
      allowedSortFields: ['createdAt', 'updatedAt', 'amount', 'status'],
      filterFields: {
        status: 'status',
        gateway: 'gateway',
        order: 'order',
      },
      searchFields: ['gatewayOrderId', 'gatewayPaymentId'],
    });

    if (auth.role !== 'admin') {
      listQuery.filter.user = auth.sub;
    } else if (query.user) {
      listQuery.filter.user = query.user;
    }

    const { items, total } = await paymentRepository.list(listQuery);
    return {
      payments: items.map((p) => formatPayment(p)),
      pagination: buildPagination({
        page: listQuery.page,
        limit: listQuery.limit,
        total,
      }),
      razorpayMode: 'test',
    };
  }

  async #markOrderFailedAndRelease(order, auth, reason) {
    if (order.stockReserved) {
      await releaseStockForLines(order.items, {
        userId: auth.role === 'user' ? auth.sub : order.user,
        orderNumber: order.orderNumber,
        reason: 'payment_failed',
      });
      inventoryEvents.publish({
        reason: 'payment_failed_release',
        orderNumber: order.orderNumber,
        stockIds: stockIdsFromOrder(order),
      });
    }

    return orderRepository.updateById(order._id, {
      status: 'CANCELLED',
      paymentStatus: 'FAILED',
      stockReserved: false,
      cancelledAt: new Date(),
    });
  }
}

module.exports = new PaymentService();
module.exports.formatPayment = formatPayment;
module.exports.ownerUserId = ownerUserId;
module.exports.assertOwnedByAuth = assertOwnedByAuth;
