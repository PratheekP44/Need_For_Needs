'use strict';

const mongoose = require('mongoose');
const { ACTIVITY_ACTIONS, ACTIVITY_ENTITIES } = require('./enums');

const activityLogSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    admin: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Admin',
      default: null,
    },
    action: {
      type: String,
      enum: {
        values: ACTIVITY_ACTIONS,
        message: 'Invalid activity action',
      },
      required: [true, 'Activity action is required'],
    },
    entity: {
      type: String,
      enum: {
        values: ACTIVITY_ENTITIES,
        message: 'Invalid activity entity',
      },
      required: [true, 'Activity entity is required'],
    },
    entityId: {
      type: mongoose.Schema.Types.ObjectId,
      required: [true, 'Activity entityId is required'],
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
    timestamp: {
      type: Date,
      required: true,
      default: Date.now,
    },
  },
  {
    versionKey: false,
    collection: 'activity_logs',
  },
);

activityLogSchema.index({ timestamp: -1 });
activityLogSchema.index({ user: 1, timestamp: -1 });
activityLogSchema.index({ admin: 1, timestamp: -1 });
activityLogSchema.index({ entity: 1, entityId: 1, timestamp: -1 });
activityLogSchema.index({ action: 1, timestamp: -1 });

const ActivityLog =
  mongoose.models.ActivityLog || mongoose.model('ActivityLog', activityLogSchema);

module.exports = ActivityLog;
