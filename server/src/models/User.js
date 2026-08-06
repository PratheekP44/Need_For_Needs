'use strict';

const mongoose = require('mongoose');
const { USER_ROLES, USER_STATUSES } = require('./enums');

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

const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'User name is required'],
      trim: true,
      minlength: [2, 'User name must be at least 2 characters'],
      maxlength: [100, 'User name cannot exceed 100 characters'],
    },
    email: {
      type: String,
      required: [true, 'User email is required'],
      trim: true,
      lowercase: true,
      maxlength: [254, 'User email cannot exceed 254 characters'],
      match: [emailRegex, 'Please provide a valid email address'],
    },
    phone: {
      type: String,
      required: [true, 'User phone is required'],
      trim: true,
      match: [phoneRegex, 'Please provide a valid phone number'],
    },
    password: {
      type: String,
      required: [true, 'Password is required'],
      minlength: [8, 'Password must be at least 8 characters'],
      select: false,
    },
    role: {
      type: String,
      enum: {
        values: USER_ROLES,
        message: 'Invalid user role',
      },
      default: 'user',
      required: true,
    },
    status: {
      type: String,
      enum: {
        values: USER_STATUSES,
        message: 'Invalid user status',
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
    collection: 'users',
  },
);

userSchema.index({ email: 1 }, { unique: true });
userSchema.index({ phone: 1 }, { unique: true });
userSchema.index({ status: 1 });
userSchema.index({ role: 1, status: 1 });

userSchema.methods.toSafeObject = function toSafeObject() {
  return {
    id: this._id,
    name: this.name,
    email: this.email,
    phone: this.phone,
    role: 'user',
    accountType: 'user',
    userRole: this.role,
    status: this.status,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
  };
};

const User = mongoose.models.User || mongoose.model('User', userSchema);

module.exports = User;
