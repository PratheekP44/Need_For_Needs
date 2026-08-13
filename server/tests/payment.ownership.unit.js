'use strict';

/**
 * Unit coverage for payment ownership id resolution
 * (populated User doc vs raw ObjectId).
 */

const {
  ownerUserId,
  assertOwnedByAuth,
} = require('../src/services/payment.service');
const AppError = require('../src/utils/AppError');

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

const ownerId = '507f1f77bcf86cd799439011';
const otherId = '507f1f77bcf86cd799439099';

assert(ownerUserId(ownerId) === ownerId, 'raw id should round-trip');

assert(
  ownerUserId({ _id: ownerId, name: 'A', email: 'a@test.com' }) === ownerId,
  'populated user should use _id',
);

const populated = { _id: ownerId, name: 'A' };
assert(
  String(populated) !== ownerId,
  'String(populatedObject) must not equal ObjectId (regression guard)',
);
assert(
  ownerUserId(populated) === ownerId,
  'ownerUserId must fix populated comparison',
);

assertOwnedByAuth({ role: 'user', sub: ownerId }, populated);

let rejected = false;
try {
  assertOwnedByAuth({ role: 'user', sub: otherId }, populated);
} catch (e) {
  rejected = e instanceof AppError && e.statusCode === 403 && e.message === 'Forbidden';
}
assert(rejected, 'other user must get 403 Forbidden');

assertOwnedByAuth({ role: 'admin', sub: otherId }, populated);

console.log('payment.ownership.unit.js OK');
