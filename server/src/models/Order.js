'use strict';

const mongoose = require('mongoose');
const { ORDER_STATUSES, ORDER_PAYMENT_STATUSES } = require('./enums');

const orderItemSchema = new mongoose.Schema(
  {
    item: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Item',
      required: [true, 'Order item reference is required'],
    },
    stock: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Stock',
      required: [true, 'Stock reference is required'],
    },
    locker: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Locker',
      required: [true, 'Locker reference is required'],
    },
    box: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Box',
      required: [true, 'Box reference is required'],
    },
    quantity: {
      type: Number,
      required: [true, 'Order item quantity is required'],
      min: [1, 'Order item quantity must be at least 1'],
    },
    priceAtPurchase: {
      type: Number,
      required: [true, 'priceAtPurchase is required'],
      min: [0, 'priceAtPurchase cannot be negative'],
    },
    gstPercentage: {
      type: Number,
      required: true,
      min: 0,
      max: 100,
      default: 0,
    },
    subtotal: {
      type: Number,
      required: [true, 'Line subtotal is required'],
      min: [0, 'Line subtotal cannot be negative'],
    },
  },
  { _id: false },
);

const orderSchema = new mongoose.Schema(
  {
    orderNumber: {
      type: String,
      required: [true, 'Order number is required'],
      trim: true,
      uppercase: true,
      maxlength: [40, 'Order number cannot exceed 40 characters'],
    },
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'User reference is required'],
    },
    locker: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Locker',
      required: [true, 'Locker reference is required'],
    },
    cart: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Cart',
      default: null,
    },
    items: {
      type: [orderItemSchema],
      default: [],
      validate: {
        validator(value) {
          return Array.isArray(value) && value.length > 0;
        },
        message: 'Order must include at least one item',
      },
    },
    subtotal: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
    },
    tax: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
    },
    discount: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
    },
    grandTotal: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
    },
    status: {
      type: String,
      enum: {
        values: ORDER_STATUSES,
        message: 'Invalid order status',
      },
      default: 'CREATED',
      required: true,
    },
    paymentStatus: {
      type: String,
      enum: {
        values: ORDER_PAYMENT_STATUSES,
        message: 'Invalid payment status',
      },
      default: 'PENDING',
      required: true,
    },
    stockReserved: {
      type: Boolean,
      default: false,
    },
    expiresAt: {
      type: Date,
      default: null,
    },
    cancelledAt: {
      type: Date,
      default: null,
    },
    collectedAt: {
      type: Date,
      default: null,
    },
    /** Successful Payment document (set after Razorpay verify). */
    payment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Payment',
      default: null,
    },
    /** Ledger Transaction document (set after Razorpay verify). */
    transaction: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Transaction',
      default: null,
    },
    /** Gateway payment id denormalized for order lists / success UI. */
    gatewayPaymentId: {
      type: String,
      trim: true,
      default: '',
      maxlength: [80, 'Gateway payment id cannot exceed 80 characters'],
    },
    collectionToken: {
      type: String,
      trim: true,
      default: '',
      maxlength: [200, 'Collection token cannot exceed 200 characters'],
    },
    collectionTokenExpiresAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    collection: 'orders',
  },
);

orderSchema.index({ orderNumber: 1 }, { unique: true });
orderSchema.index({ user: 1, createdAt: -1 });
orderSchema.index({ locker: 1, status: 1 });
orderSchema.index({ status: 1, expiresAt: 1 });
orderSchema.index({ paymentStatus: 1, createdAt: -1 });

const Order = mongoose.models.Order || mongoose.model('Order', orderSchema);

module.exports = Order;
