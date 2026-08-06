'use strict';

const User = require('../models/User');
const Admin = require('../models/Admin');

class AuthRepository {
  async findUserByEmail(email, { withSensitive = false } = {}) {
    const query = User.findOne({ email: email.toLowerCase() });
    if (withSensitive) {
      query.select('+password +refreshTokens');
    }
    return query.exec();
  }

  async findAdminByEmail(email, { withSensitive = false } = {}) {
    const query = Admin.findOne({ email: email.toLowerCase() });
    if (withSensitive) {
      query.select('+password +refreshTokens');
    }
    return query.exec();
  }

  async findUserByPhone(phone) {
    return User.findOne({ phone }).exec();
  }

  async findAdminByPhone(phone) {
    return Admin.findOne({ phone }).exec();
  }

  async findUserById(id, { withSensitive = false } = {}) {
    const query = User.findById(id);
    if (withSensitive) {
      query.select('+password +refreshTokens');
    }
    return query.exec();
  }

  async findAdminById(id, { withSensitive = false } = {}) {
    const query = Admin.findById(id);
    if (withSensitive) {
      query.select('+password +refreshTokens');
    }
    return query.exec();
  }

  async emailExists(email) {
    const normalized = email.toLowerCase();
    const [user, admin] = await Promise.all([
      User.exists({ email: normalized }),
      Admin.exists({ email: normalized }),
    ]);
    return Boolean(user || admin);
  }

  async phoneExists(phone) {
    const [user, admin] = await Promise.all([
      User.exists({ phone }),
      Admin.exists({ phone }),
    ]);
    return Boolean(user || admin);
  }

  async createUser(data) {
    const user = await User.create(data);
    return user;
  }

  async createAdmin(data) {
    const admin = await Admin.create(data);
    return admin;
  }

  async saveAccount(account) {
    return account.save();
  }
}

module.exports = new AuthRepository();
