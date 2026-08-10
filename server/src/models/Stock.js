'use strict';

const mongoose = require('mongoose');
const { STOCK_STATUSES } = require('./enums');

/**
 * Stock links a physical Box to a catalog Item.
 * One Box = one Stock record = one physical unit (currentQuantity is always 0 or 1).
 */
const stockSchema = new mongoose.Schema(
  {
    stockId: {
      type: String,
      required: [true, 'Stock ID is required'],
      trim: true,
      uppercase: true,
      maxlength: [50, 'Stock ID cannot exceed 50 characters'],
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
    item: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Item',
      required: [true, 'Item reference is required'],
    },
    currentQuantity: {
      type: Number,
      required: [true, 'Current quantity is required'],
      min: [0, 'Current quantity cannot be negative'],
      max: [1, 'Each physical box holds at most one item'],
      default: 0,
    },
    maximumQuantity: {
      type: Number,
      required: [true, 'Maximum quantity is required'],
      min: [1, 'Maximum quantity must be at least 1'],
      max: [1, 'Each physical box holds at most one item'],
      default: 1,
    },
    reorderLevel: {
      type: Number,
      required: [true, 'Reorder level is required'],
      min: [0, 'Reorder level cannot be negative'],
      default: 0,
    },
    expiryDate: {
      type: Date,
      default: null,
    },
    batchNumber: {
      type: String,
      trim: true,
      default: '',
      maxlength: [64, 'Batch number cannot exceed 64 characters'],
    },
    supplierName: {
      type: String,
      trim: true,
      default: '',
      maxlength: [120, 'Supplier name cannot exceed 120 characters'],
    },
    purchaseDate: {
      type: Date,
      default: null,
    },
    status: {
      type: String,
      enum: {
        values: STOCK_STATUSES,
        message: 'Invalid stock status',
      },
      default: 'OUT_OF_STOCK',
      required: true,
    },
    lastRestocked: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    collection: 'stocks',
  },
);

stockSchema.index({ stockId: 1 }, { unique: true });
stockSchema.index({ box: 1 }, { unique: true });
stockSchema.index({ locker: 1, status: 1 });
stockSchema.index({ item: 1 });
stockSchema.index({ status: 1 });
stockSchema.index({ currentQuantity: 1 });

stockSchema.pre('validate', function validateQuantities() {
  if (
    this.currentQuantity != null &&
    this.maximumQuantity != null &&
    this.currentQuantity > this.maximumQuantity
  ) {
    this.invalidate(
      'currentQuantity',
      'Current quantity cannot exceed maximumQuantity',
    );
  }

  if (
    this.reorderLevel != null &&
    this.maximumQuantity != null &&
    this.reorderLevel > this.maximumQuantity
  ) {
    this.invalidate(
      'reorderLevel',
      'Reorder level cannot exceed maximumQuantity',
    );
  }
});

stockSchema.methods.toPublicObject = function toPublicObject(extra = {}) {
  return {
    id: this._id,
    stockId: this.stockId,
    locker: this.locker,
    box: this.box,
    item: this.item,
    currentQuantity: this.currentQuantity,
    maximumQuantity: this.maximumQuantity,
    reorderLevel: this.reorderLevel,
    expiryDate: this.expiryDate,
    batchNumber: this.batchNumber,
    supplierName: this.supplierName,
    purchaseDate: this.purchaseDate,
    status: this.status,
    lastRestocked: this.lastRestocked,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
    ...extra,
  };
};

const Stock = mongoose.models.Stock || mongoose.model('Stock', stockSchema);

module.exports = Stock;
