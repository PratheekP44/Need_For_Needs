'use strict';

const mongoose = require('mongoose');
const { PAYMENT_GATEWAYS, PAYMENT_STATUSES } = require('./enums');

const paymentSchema = new mongoose.Schema(
  {
    order: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Order',
      required: [true, 'Order reference is required'],
    },
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'User reference is required'],
    },
    gateway: {
      type: String,
      enum: {
        values: PAYMENT_GATEWAYS,
        message: 'Invalid payment gateway',
      },
      required: [true, 'Payment gateway is required'],
      default: 'razorpay',
    },
    gatewayOrderId: {
      type: String,
      trim: true,
      default: null,
      maxlength: [120, 'Gateway order ID cannot exceed 120 characters'],
    },
    gatewayPaymentId: {
      type: String,
      trim: true,
      default: null,
      maxlength: [120, 'Gateway payment ID cannot exceed 120 characters'],
    },
    signature: {
      type: String,
      trim: true,
      default: null,
      maxlength: [256, 'Payment signature cannot exceed 256 characters'],
    },
    currency: {
      type: String,
      trim: true,
      uppercase: true,
      default: 'INR',
      maxlength: [8, 'Currency code cannot exceed 8 characters'],
    },
    amount: {
      type: Number,
      required: [true, 'Payment amount is required'],
      min: [0, 'Payment amount cannot be negative'],
    },
    paymentMethod: {
      type: String,
      trim: true,
      default: null,
      maxlength: [64, 'Payment method cannot exceed 64 characters'],
    },
    /**
     * True when created under RAZORPAY_MOCK (local/CI). Excluded from the
     * unique gatewayPaymentId index so mock captures never block real ones.
     */
    isMock: {
      type: Boolean,
      default: false,
      required: true,
    },
    status: {
      type: String,
      enum: {
        values: PAYMENT_STATUSES,
        message: 'Invalid payment status',
      },
      default: 'CREATED',
      required: true,
    },
    failureReason: {
      type: String,
      trim: true,
      default: null,
      maxlength: [500, 'Failure reason cannot exceed 500 characters'],
    },
    refundNote: {
      type: String,
      trim: true,
      default: null,
      maxlength: [500, 'Refund note cannot exceed 500 characters'],
    },
    verifiedAt: {
      type: Date,
      default: null,
    },
    failedAt: {
      type: Date,
      default: null,
    },
    refundedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    collection: 'payments',
  },
);

paymentSchema.index({ order: 1 });
paymentSchema.index({ user: 1, createdAt: -1 });
paymentSchema.index({ gatewayOrderId: 1 }, { unique: true, sparse: true });
// Unique gatewayPaymentId for real SUCCESS captures only.
// MongoDB partial indexes allow equality / $type / $and — not $ne / $not.
paymentSchema.index(
  { gatewayPaymentId: 1 },
  {
    unique: true,
    name: 'gatewayPaymentId_success_real_unique',
    partialFilterExpression: {
      status: 'SUCCESS',
      isMock: false,
      gatewayPaymentId: { $type: 'string' },
    },
  },
);
paymentSchema.index({ status: 1, createdAt: -1 });
paymentSchema.index({ gateway: 1, status: 1 });
paymentSchema.index({ isMock: 1, status: 1 });

const Payment = mongoose.models.Payment || mongoose.model('Payment', paymentSchema);

module.exports = Payment;
