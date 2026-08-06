'use strict';

const mongoose = require('mongoose');
const { CART_STATUSES } = require('./enums');

const cartItemSchema = new mongoose.Schema(
  {
    item: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Item',
      required: [true, 'Cart item reference is required'],
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
      required: [true, 'Quantity is required'],
      min: [1, 'Quantity must be at least 1'],
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
  { _id: true },
);

const cartSchema = new mongoose.Schema(
  {
    cartId: {
      type: String,
      required: [true, 'Cart ID is required'],
      trim: true,
      uppercase: true,
      maxlength: [50, 'Cart ID cannot exceed 50 characters'],
    },
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'User reference is required'],
    },
    items: {
      type: [cartItemSchema],
      default: [],
    },
    subtotal: {
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
    tax: {
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
        values: CART_STATUSES,
        message: 'Invalid cart status',
      },
      default: 'ACTIVE',
      required: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    collection: 'carts',
  },
);

cartSchema.index({ cartId: 1 }, { unique: true });
cartSchema.index({ user: 1, status: 1 });
cartSchema.index({ user: 1, updatedAt: -1 });

cartSchema.methods.recalculateTotals = function recalculateTotals() {
  let subtotal = 0;
  let tax = 0;

  this.items.forEach((line) => {
    const lineSubtotal = Number(line.quantity) * Number(line.priceAtPurchase);
    line.subtotal = Number(lineSubtotal.toFixed(2));
    subtotal += line.subtotal;
    tax += line.subtotal * (Number(line.gstPercentage) || 0) / 100;
  });

  this.subtotal = Number(subtotal.toFixed(2));
  this.tax = Number(tax.toFixed(2));
  this.discount = Number(this.discount || 0);
  this.grandTotal = Number(
    Math.max(0, this.subtotal + this.tax - this.discount).toFixed(2),
  );
};

const Cart = mongoose.models.Cart || mongoose.model('Cart', cartSchema);

module.exports = Cart;
