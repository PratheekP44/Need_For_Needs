'use strict';

const mongoose = require('mongoose');
const { LOCKER_STATUSES } = require('./enums');

const lockerSchema = new mongoose.Schema(
  {
    lockerId: {
      type: String,
      required: [true, 'Locker ID is required'],
      trim: true,
      uppercase: true,
      maxlength: [50, 'Locker ID cannot exceed 50 characters'],
    },
    lockerName: {
      type: String,
      required: [true, 'Locker name is required'],
      trim: true,
      minlength: [2, 'Locker name must be at least 2 characters'],
      maxlength: [120, 'Locker name cannot exceed 120 characters'],
    },
    latitude: {
      type: Number,
      required: [true, 'Latitude is required'],
      min: [-90, 'Latitude must be >= -90'],
      max: [90, 'Latitude must be <= 90'],
    },
    longitude: {
      type: Number,
      required: [true, 'Longitude is required'],
      min: [-180, 'Longitude must be >= -180'],
      max: [180, 'Longitude must be <= 180'],
    },
    BLEDevice: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'BLEDevice',
      default: null,
    },
    status: {
      type: String,
      enum: {
        values: LOCKER_STATUSES,
        message: 'Invalid locker status',
      },
      default: 'OFFLINE',
      required: true,
    },
    totalBoxes: {
      type: Number,
      required: [true, 'Total boxes is required'],
      min: [1, 'Locker must have at least 1 box'],
      max: [500, 'Total boxes cannot exceed 500'],
      default: 1,
    },
    description: {
      type: String,
      trim: true,
      default: '',
      maxlength: [1000, 'Description cannot exceed 1000 characters'],
    },
  },
  {
    timestamps: true,
    versionKey: false,
    collection: 'lockers',
  },
);

lockerSchema.index({ lockerId: 1 }, { unique: true });
lockerSchema.index({ status: 1 });
lockerSchema.index({ BLEDevice: 1 });
lockerSchema.index({ latitude: 1, longitude: 1 });
lockerSchema.index({ lockerName: 'text', description: 'text', lockerId: 'text' });

lockerSchema.methods.toPublicObject = function toPublicObject(extra = {}) {
  return {
    id: this._id,
    lockerId: this.lockerId,
    lockerName: this.lockerName,
    latitude: this.latitude,
    longitude: this.longitude,
    BLEDevice: this.BLEDevice,
    status: this.status,
    totalBoxes: this.totalBoxes,
    description: this.description,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
    ...extra,
  };
};

const Locker = mongoose.models.Locker || mongoose.model('Locker', lockerSchema);

module.exports = Locker;
