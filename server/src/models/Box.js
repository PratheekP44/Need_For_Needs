'use strict';

const mongoose = require('mongoose');
const { BOX_STATUSES, BOX_DOOR_STATES } = require('./enums');

/**
 * Box is a physical compartment only.
 * Item / quantity / price belong to Inventory (next phase).
 */
const boxSchema = new mongoose.Schema(
  {
    boxId: {
      type: String,
      required: [true, 'Box ID is required'],
      trim: true,
      uppercase: true,
      maxlength: [50, 'Box ID cannot exceed 50 characters'],
    },
    locker: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Locker',
      required: [true, 'Locker reference is required'],
    },
    boxNumber: {
      type: Number,
      required: [true, 'Box number is required'],
      min: [1, 'Box number must be at least 1'],
    },
    status: {
      type: String,
      enum: {
        values: BOX_STATUSES,
        message: 'Invalid box status',
      },
      default: 'EMPTY',
      required: true,
    },
    isEmpty: {
      type: Boolean,
      required: true,
      default: true,
    },
    doorState: {
      type: String,
      enum: {
        values: BOX_DOOR_STATES,
        message: 'Invalid door state',
      },
      default: 'CLOSED',
      required: true,
    },
    lastOpened: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    collection: 'boxes',
  },
);

boxSchema.index({ boxId: 1 }, { unique: true });
boxSchema.index({ locker: 1, boxNumber: 1 }, { unique: true });
boxSchema.index({ locker: 1, status: 1 });
boxSchema.index({ status: 1, doorState: 1 });
boxSchema.index({ isEmpty: 1 });

boxSchema.pre('validate', function syncEmptyFlag() {
  if (this.status === 'EMPTY') {
    this.isEmpty = true;
  }
});

boxSchema.methods.toPublicObject = function toPublicObject(extra = {}) {
  return {
    id: this._id,
    boxId: this.boxId,
    locker: this.locker,
    boxNumber: this.boxNumber,
    status: this.status,
    isEmpty: this.isEmpty,
    doorState: this.doorState,
    lastOpened: this.lastOpened,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
    ...extra,
  };
};

const Box = mongoose.models.Box || mongoose.model('Box', boxSchema);

module.exports = Box;
