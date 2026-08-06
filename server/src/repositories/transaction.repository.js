'use strict';

const Transaction = require('../models/Transaction');

class TransactionRepository {
  async create(data) {
    return Transaction.create(data);
  }

  async findById(id) {
    return Transaction.findById(id).exec();
  }

  async findByPaymentId(paymentId) {
    return Transaction.findOne({ payment: paymentId }).exec();
  }

  async findByOrderId(orderId) {
    return Transaction.findOne({ order: orderId }).sort({ createdAt: -1 }).exec();
  }

  async updateById(id, data) {
    return Transaction.findByIdAndUpdate(id, data, {
      new: true,
      runValidators: true,
    }).exec();
  }
}

module.exports = new TransactionRepository();
