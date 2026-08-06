'use strict';

/**
 * Upserts the permanent development administrator account.
 *
 * Usage:
 *   npm run seed:admin
 *
 * Safe to run repeatedly — updates password/role/status if the admin exists.
 */

const mongoose = require('mongoose');
const { loadEnv } = require('../src/config/env');
const { connectDatabase, disconnectDatabase } = require('../src/database/connection');
const { hashPassword } = require('../src/utils/password');
const Admin = require('../src/models/Admin');
const User = require('../src/models/User');
const { ADMIN_PERMISSIONS } = require('../src/models/enums');
const logger = require('../src/config/logger');

const ADMIN_SEED = Object.freeze({
  name: 'Pratheek P Reddy',
  email: 'pratheekpreddy@gmail.com',
  phone: '+919900112233',
  password: 'Alpha001',
  status: 'active',
  permissions: [...ADMIN_PERMISSIONS],
});

async function seedAdmin() {
  const config = loadEnv();
  logger.info(`Loaded env: ${config.envPath}`);
  await connectDatabase(config.mongoUri);

  const email = ADMIN_SEED.email.toLowerCase();
  const passwordHash = await hashPassword(
    ADMIN_SEED.password,
    config.bcryptSaltRounds,
  );

  // If a User exists with the same email, keep it but warn — login prefers
  // a matching Admin password, so the Admin account still works.
  const existingUser = await User.findOne({ email }).exec();
  if (existingUser) {
    logger.warn(
      `A User document also exists for ${email}. Admin login will still work ` +
        `when the Admin password matches (Alpha001).`,
    );
  }

  let admin = await Admin.findOne({ email }).select('+password').exec();

  if (admin) {
    admin.name = ADMIN_SEED.name;
    admin.phone = ADMIN_SEED.phone;
    admin.password = passwordHash;
    admin.status = ADMIN_SEED.status;
    admin.permissions = ADMIN_SEED.permissions;
    admin.refreshTokens = [];
    await admin.save();
    logger.info(`Updated existing admin: ${email} (id=${admin._id})`);
  } else {
    // Phone uniqueness: clear conflicting admin phone if needed
    const phoneClash = await Admin.findOne({ phone: ADMIN_SEED.phone }).exec();
    if (phoneClash && phoneClash.email !== email) {
      throw new Error(
        `Admin phone ${ADMIN_SEED.phone} already used by ${phoneClash.email}`,
      );
    }

    admin = await Admin.create({
      name: ADMIN_SEED.name,
      email,
      phone: ADMIN_SEED.phone,
      password: passwordHash,
      status: ADMIN_SEED.status,
      permissions: ADMIN_SEED.permissions,
      refreshTokens: [],
    });
    logger.info(`Created admin: ${email} (id=${admin._id})`);
  }

  const safe = admin.toSafeObject();
  logger.info('Admin seed complete', {
    id: String(safe.id),
    email: safe.email,
    role: safe.role,
    accountType: safe.accountType,
    status: safe.status,
    permissions: safe.permissions,
  });

  await disconnectDatabase();
}

seedAdmin().catch(async (error) => {
  logger.error('Admin seed failed', {
    message: error.message,
    stack: error.stack,
  });
  try {
    await disconnectDatabase();
  } catch (_) {
    // ignore
  }
  if (mongoose.connection.readyState !== 0) {
    await mongoose.disconnect().catch(() => {});
  }
  process.exit(1);
});
