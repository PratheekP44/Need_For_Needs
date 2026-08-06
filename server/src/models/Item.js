'use strict';

const mongoose = require('mongoose');
const { ITEM_CATEGORIES, ITEM_UNITS } = require('./enums');

const itemSchema = new mongoose.Schema(
  {
    itemId: {
      type: String,
      required: [true, 'Item ID is required'],
      trim: true,
      uppercase: true,
      maxlength: [50, 'Item ID cannot exceed 50 characters'],
    },
    name: {
      type: String,
      required: [true, 'Item name is required'],
      trim: true,
      minlength: [2, 'Item name must be at least 2 characters'],
      maxlength: [150, 'Item name cannot exceed 150 characters'],
    },
    description: {
      type: String,
      required: [true, 'Item description is required'],
      trim: true,
      maxlength: [2000, 'Item description cannot exceed 2000 characters'],
    },
    category: {
      type: String,
      enum: {
        values: ITEM_CATEGORIES,
        message: 'Invalid item category',
      },
      required: [true, 'Item category is required'],
    },
    brand: {
      type: String,
      required: [true, 'Brand is required'],
      trim: true,
      maxlength: [100, 'Brand cannot exceed 100 characters'],
    },
    barcode: {
      type: String,
      required: [true, 'Barcode is required'],
      trim: true,
      maxlength: [64, 'Barcode cannot exceed 64 characters'],
    },
    imageUrl: {
      type: String,
      trim: true,
      default: '',
      maxlength: [1000, 'Image URL cannot exceed 1000 characters'],
    },
    sellingPrice: {
      type: Number,
      required: [true, 'Selling price is required'],
      min: [0, 'Selling price cannot be negative'],
    },
    costPrice: {
      type: Number,
      required: [true, 'Cost price is required'],
      min: [0, 'Cost price cannot be negative'],
    },
    gstPercentage: {
      type: Number,
      required: [true, 'GST percentage is required'],
      min: [0, 'GST percentage cannot be negative'],
      max: [100, 'GST percentage cannot exceed 100'],
      default: 0,
    },
    unit: {
      type: String,
      enum: {
        values: ITEM_UNITS,
        message: 'Invalid unit',
      },
      default: 'piece',
      required: true,
    },
    isActive: {
      type: Boolean,
      default: true,
      required: true,
    },
    tags: {
      type: [
        {
          type: String,
          trim: true,
          maxlength: [40, 'Tag cannot exceed 40 characters'],
        },
      ],
      default: [],
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Admin',
      default: null,
    },
    updatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Admin',
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    collection: 'items',
  },
);

itemSchema.index({ itemId: 1 }, { unique: true });
itemSchema.index({ barcode: 1 }, { unique: true });
itemSchema.index({ name: 1 });
itemSchema.index({ category: 1, isActive: 1 });
itemSchema.index({ brand: 1 });
itemSchema.index({ sellingPrice: 1 });
itemSchema.index({ name: 'text', description: 'text', brand: 'text', barcode: 'text' });

itemSchema.pre('validate', function validatePrices() {
  if (
    this.sellingPrice != null &&
    this.costPrice != null &&
    this.sellingPrice < this.costPrice
  ) {
    this.invalidate('sellingPrice', 'Selling price must be greater than or equal to cost price');
  }
});

itemSchema.methods.toPublicObject = function toPublicObject(extra = {}) {
  return {
    id: this._id,
    itemId: this.itemId,
    name: this.name,
    description: this.description,
    category: this.category,
    brand: this.brand,
    barcode: this.barcode,
    imageUrl: this.imageUrl,
    sellingPrice: this.sellingPrice,
    costPrice: this.costPrice,
    gstPercentage: this.gstPercentage,
    unit: this.unit,
    isActive: this.isActive,
    tags: this.tags,
    createdBy: this.createdBy,
    updatedBy: this.updatedBy,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
    ...extra,
  };
};

const Item = mongoose.models.Item || mongoose.model('Item', itemSchema);

module.exports = Item;
