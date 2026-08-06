'use strict';

const mongoose = require('mongoose');
const { TRANSACTION_STATUSES } = require('./enums');

const transactionSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'User reference is required'],
    },
    order: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Order',
      required: [true, 'Order reference is required'],
    },
    payment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Payment',
      required: [true, 'Payment reference is required'],
    },
    amount: {
      type: Number,
      required: [true, 'Transaction amount is required'],
      min: [0, 'Transaction amount cannot be negative'],
    },
    status: {
      type: String,
      enum: {
        values: TRANSACTION_STATUSES,
        message: 'Invalid transaction status',
      },
      default: 'initiated',
      required: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    collection: 'transactions',
  },
);

transactionSchema.index({ user: 1, createdAt: -1 });
transactionSchema.index({ order: 1 });
transactionSchema.index({ payment: 1 });
transactionSchema.index({ status: 1, createdAt: -1 });

const Transaction =
  mongoose.models.Transaction || mongoose.model('Transaction', transactionSchema);

module.exports = Transaction;
