'use strict';

/**
 * Shared enums for Campus Essentials Mongoose schemas.
 * Status / role values are centralized for future scalability.
 */

const USER_ROLES = Object.freeze(['user', 'student', 'staff']);
const USER_STATUSES = Object.freeze(['active', 'inactive', 'blocked', 'pending']);
const ADMIN_STATUSES = Object.freeze(['active', 'inactive', 'blocked']);
const AUTH_ACCOUNT_TYPES = Object.freeze(['user', 'admin']);
const AUTH_ROLES = Object.freeze(['user', 'admin']);

const ADMIN_PERMISSIONS = Object.freeze([
  'manage_lockers',
  'manage_inventory',
  'manage_orders',
  'manage_users',
  'view_reports',
  'manage_payments',
  'manage_ble',
  'super_admin',
]);

const LOCKER_STATUSES = Object.freeze([
  'ACTIVE',
  'OFFLINE',
  'MAINTENANCE',
  'DISABLED',
]);

const BOX_STATUSES = Object.freeze([
  'EMPTY',
  'AVAILABLE',
  'RESERVED',
  'MAINTENANCE',
  'FAULT',
]);

const BOX_DOOR_STATES = Object.freeze(['OPEN', 'CLOSED']);

const ITEM_CATEGORIES = Object.freeze([
  'MEDICINE',
  'ELECTRONICS',
  'STATIONERY',
  'PERSONAL_CARE',
  'FOOD',
  'BEVERAGE',
  'ACCESSORY',
  'MISC',
]);

const ITEM_UNITS = Object.freeze([
  'piece',
  'pack',
  'box',
  'bottle',
  'can',
  'kg',
  'g',
  'ml',
  'l',
  'other',
]);

const STOCK_STATUSES = Object.freeze([
  'IN_STOCK',
  'LOW_STOCK',
  'OUT_OF_STOCK',
  'EXPIRED',
  'DISABLED',
]);

const CART_STATUSES = Object.freeze(['ACTIVE', 'CHECKED_OUT', 'ABANDONED']);

const ORDER_STATUSES = Object.freeze([
  'CREATED',
  'WAITING_PAYMENT',
  'PAYMENT_SUCCESS',
  'READY_FOR_COLLECTION',
  'COLLECTED',
  'CANCELLED',
  'EXPIRED',
]);

const ORDER_PAYMENT_STATUSES = Object.freeze([
  'PENDING',
  'SUCCESS',
  'FAILED',
  'REFUNDED',
]);

const PAYMENT_GATEWAYS = Object.freeze(['razorpay', 'manual', 'other']);
const PAYMENT_STATUSES = Object.freeze([
  'CREATED',
  'PENDING',
  'SUCCESS',
  'FAILED',
  'REFUNDED',
]);

const BLE_DEVICE_STATUSES = Object.freeze([
  'active',
  'inactive',
  'pairing',
  'error',
  'maintenance',
]);

const TRANSACTION_STATUSES = Object.freeze([
  'initiated',
  'success',
  'failed',
  'reversed',
]);

const ACTIVITY_ACTIONS = Object.freeze([
  'create',
  'update',
  'delete',
  'login',
  'logout',
  'status_change',
  'payment',
  'payment_created',
  'payment_verified',
  'payment_failed',
  'payment_refunded',
  'collect',
  'open_locker',
  'restock',
  'move_stock',
  'assign_stock',
  'assign_stock_batch',
  'remove_stock',
  'cart_add',
  'cart_update',
  'cart_remove',
  'cart_clear',
  'checkout',
  'order_cancel',
  'order_expire',
  'stock_reserve',
  'stock_release',
  'other',
]);

const ACTIVITY_ENTITIES = Object.freeze([
  'User',
  'Admin',
  'Locker',
  'Box',
  'Item',
  'Stock',
  'Cart',
  'Order',
  'Payment',
  'BLEDevice',
  'Transaction',
  'System',
]);

module.exports = {
  USER_ROLES,
  USER_STATUSES,
  ADMIN_STATUSES,
  AUTH_ACCOUNT_TYPES,
  AUTH_ROLES,
  ADMIN_PERMISSIONS,
  LOCKER_STATUSES,
  BOX_STATUSES,
  BOX_DOOR_STATES,
  ITEM_CATEGORIES,
  ITEM_UNITS,
  STOCK_STATUSES,
  CART_STATUSES,
  ORDER_STATUSES,
  ORDER_PAYMENT_STATUSES,
  PAYMENT_GATEWAYS,
  PAYMENT_STATUSES,
  BLE_DEVICE_STATUSES,
  TRANSACTION_STATUSES,
  ACTIVITY_ACTIONS,
  ACTIVITY_ENTITIES,
};
