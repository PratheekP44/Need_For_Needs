'use strict';

const mongoose = require('mongoose');
const { BLE_DEVICE_STATUSES } = require('./enums');

const macAddressRegex = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/;

const bleDeviceSchema = new mongoose.Schema(
  {
    deviceName: {
      type: String,
      required: [true, 'BLE device name is required'],
      trim: true,
      minlength: [2, 'Device name must be at least 2 characters'],
      maxlength: [100, 'Device name cannot exceed 100 characters'],
    },
    macAddress: {
      type: String,
      required: [true, 'MAC address is required'],
      trim: true,
      uppercase: true,
      match: [macAddressRegex, 'Please provide a valid MAC address'],
    },
    firmwareVersion: {
      type: String,
      required: [true, 'Firmware version is required'],
      trim: true,
      maxlength: [50, 'Firmware version cannot exceed 50 characters'],
    },
    status: {
      type: String,
      enum: {
        values: BLE_DEVICE_STATUSES,
        message: 'Invalid BLE device status',
      },
      default: 'inactive',
      required: true,
    },
    locker: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Locker',
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    collection: 'ble_devices',
  },
);

bleDeviceSchema.index({ macAddress: 1 }, { unique: true });
bleDeviceSchema.index({ locker: 1 });
bleDeviceSchema.index({ status: 1 });
bleDeviceSchema.index({ deviceName: 1 });

const BLEDevice =
  mongoose.models.BLEDevice || mongoose.model('BLEDevice', bleDeviceSchema);

module.exports = BLEDevice;
