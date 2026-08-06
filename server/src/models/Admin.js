'use strict';

const mongoose = require('mongoose');
const { ADMIN_PERMISSIONS, ADMIN_STATUSES } = require('./enums');

const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const phoneRegex = /^\+?[0-9]{7,15}$/;

const refreshTokenSchema = new mongoose.Schema(
  {
    tokenHash: {
      type: String,
      required: true,
    },
    expiresAt: {
      type: Date,
      required: true,
    },
    createdAt: {
      type: Date,
      default: Date.now,
    },
  },
  { _id: false },
);

const adminSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Admin name is required'],
      trim: true,
      minlength: [2, 'Admin name must be at least 2 characters'],
      maxlength: [100, 'Admin name cannot exceed 100 characters'],
    },
    email: {
      type: String,
      required: [true, 'Admin email is required'],
      trim: true,
      lowercase: true,
      maxlength: [254, 'Admin email cannot exceed 254 characters'],
      match: [emailRegex, 'Please provide a valid email address'],
    },
    phone: {
      type: String,
      required: [true, 'Admin phone is required'],
      trim: true,
      match: [phoneRegex, 'Please provide a valid phone number'],
    },
    password: {
      type: String,
      required: [true, 'Password is required'],
      minlength: [8, 'Password must be at least 8 characters'],
      select: false,
    },
    permissions: {
      type: [
        {
          type: String,
          enum: {
            values: ADMIN_PERMISSIONS,
            message: 'Invalid admin permission',
          },
        },
      ],
      default: [],
      validate: {
        validator(value) {
          return Array.isArray(value);
        },
        message: 'Permissions must be an array',
      },
    },
    status: {
      type: String,
      enum: {
        values: ADMIN_STATUSES,
        message: 'Invalid admin status',
      },
      default: 'active',
      required: true,
    },
    refreshTokens: {
      type: [refreshTokenSchema],
      default: [],
      select: false,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    collection: 'admins',
  },
);

adminSchema.index({ email: 1 }, { unique: true });
adminSchema.index({ phone: 1 }, { unique: true });
adminSchema.index({ permissions: 1 });
adminSchema.index({ status: 1 });

adminSchema.methods.toSafeObject = function toSafeObject() {
  return {
    id: this._id,
    name: this.name,
    email: this.email,
    phone: this.phone,
    role: 'admin',
    accountType: 'admin',
    permissions: this.permissions,
    status: this.status,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
  };
};

const Admin = mongoose.models.Admin || mongoose.model('Admin', adminSchema);

module.exports = Admin;
