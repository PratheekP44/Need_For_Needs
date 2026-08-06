'use strict';

const Payment = require('../models/Payment');

class PaymentRepository {
  async create(data) {
    return Payment.create(data);
  }

  async findById(id) {
    return Payment.findById(id)
      .populate('order', 'orderNumber status paymentStatus grandTotal expiresAt')
      .exec();
  }

  async findByGatewayOrderId(gatewayOrderId) {
    return Payment.findOne({ gatewayOrderId })
      .populate('order', 'orderNumber status paymentStatus grandTotal expiresAt stockReserved items user')
      .exec();
  }

  async findLatestByOrderId(orderId) {
    return Payment.findOne({ order: orderId })
      .sort({ createdAt: -1 })
      .populate('order', 'orderNumber status paymentStatus grandTotal expiresAt stockReserved items user')
      .exec();
  }

  async findSuccessfulByOrderId(orderId) {
    return Payment.findOne({ order: orderId, status: 'SUCCESS' }).exec();
  }

  async findSuccessfulByGatewayPaymentId(gatewayPaymentId) {
    if (!gatewayPaymentId) return null;
    // Prefer a real (non-mock) SUCCESS capture for duplicate prevention.
    return Payment.findOne({
      gatewayPaymentId,
      status: 'SUCCESS',
      isMock: false,
    }).exec();
  }

  async list({ filter, sort, skip, limit }) {
    const [items, total] = await Promise.all([
      Payment.find(filter)
        .populate('order', 'orderNumber status paymentStatus grandTotal')
        .sort(sort)
        .skip(skip)
        .limit(limit)
        .exec(),
      Payment.countDocuments(filter).exec(),
    ]);
    return { items, total };
  }

  async updateById(id, data) {
    return Payment.findByIdAndUpdate(id, data, {
      new: true,
      runValidators: true,
    })
      .populate('order', 'orderNumber status paymentStatus grandTotal')
      .exec();
  }
}

module.exports = new PaymentRepository();
