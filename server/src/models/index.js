'use strict';

/**
 * Campus Essentials Mongoose models (schemas only).
 * No controllers, routes, or business logic in this phase.
 */

const enums = require('./enums');
const User = require('./User');
const Admin = require('./Admin');
const Locker = require('./Locker');
const Box = require('./Box');
const Item = require('./Item');
const Stock = require('./Stock');
const Cart = require('./Cart');
const Order = require('./Order');
const Payment = require('./Payment');
const BLEDevice = require('./BLEDevice');
const Transaction = require('./Transaction');
const ActivityLog = require('./ActivityLog');

module.exports = {
  enums,
  User,
  Admin,
  Locker,
  Box,
  Item,
  Stock,
  Cart,
  Order,
  Payment,
  BLEDevice,
  Transaction,
  ActivityLog,
};
