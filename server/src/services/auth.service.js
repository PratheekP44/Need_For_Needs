'use strict';

const authRepository = require('../repositories/auth.repository');
const AppError = require('../utils/AppError');
const { hashPassword, comparePassword, hashToken, compareToken } = require('../utils/password');
const {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
  createTokenId,
  getExpiryDate,
} = require('../utils/token');
const { loadEnv } = require('../config/env');

class AuthService {
  constructor() {
    this.config = null;
  }

  getConfig() {
    if (!this.config) {
      this.config = loadEnv();
    }
    return this.config;
  }

  buildAuthPayload(account, accountType) {
    return {
      sub: String(account._id),
      email: account.email,
      role: accountType,
      accountType,
      tokenId: createTokenId(),
    };
  }

  async issueTokenPair(account, accountType) {
    const config = this.getConfig();
    const payload = this.buildAuthPayload(account, accountType);

    const accessToken = signAccessToken(payload, config);
    const refreshToken = signRefreshToken(payload, config);
    const tokenHash = await hashToken(refreshToken);
    const expiresAt = getExpiryDate(config.jwtRefreshExpiresIn);

    account.refreshTokens = (account.refreshTokens || []).filter(
      (entry) => entry.expiresAt > new Date(),
    );
    account.refreshTokens.push({ tokenHash, expiresAt });
    await authRepository.saveAccount(account);

    return {
      accessToken,
      refreshToken,
      expiresIn: config.jwtAccessExpiresIn,
      user: account.toSafeObject(),
    };
  }

  async signup({ name, email, phone, password, accountType = 'user' }) {
    const type = accountType === 'admin' ? 'admin' : 'user';

    if (await authRepository.emailExists(email)) {
      throw new AppError('An account with this email already exists', 409);
    }

    if (await authRepository.phoneExists(phone)) {
      throw new AppError('An account with this phone number already exists', 409);
    }

    const config = this.getConfig();
    const passwordHash = await hashPassword(password, config.bcryptSaltRounds);

    let account;
    if (type === 'admin') {
      account = await authRepository.createAdmin({
        name,
        email,
        phone,
        password: passwordHash,
        permissions: [],
        status: 'active',
      });
    } else {
      account = await authRepository.createUser({
        name,
        email,
        phone,
        password: passwordHash,
        role: 'user',
        status: 'active',
      });
    }

    return this.issueTokenPair(account, type);
  }

  async login({ email, password }) {
    const normalizedEmail = email.toLowerCase();

    // Look up both collections. Prefer a matching Admin password so a
    // same-email User document cannot block administrator sign-in.
    const [userAccount, adminAccount] = await Promise.all([
      authRepository.findUserByEmail(normalizedEmail, { withSensitive: true }),
      authRepository.findAdminByEmail(normalizedEmail, { withSensitive: true }),
    ]);

    let account = null;
    let accountType = 'user';

    if (adminAccount) {
      if (adminAccount.status !== 'active') {
        throw new AppError('Account is not active', 403);
      }
      const adminMatches = await comparePassword(password, adminAccount.password);
      if (adminMatches) {
        account = adminAccount;
        accountType = 'admin';
      }
    }

    if (!account && userAccount) {
      if (userAccount.status !== 'active') {
        throw new AppError('Account is not active', 403);
      }
      const userMatches = await comparePassword(password, userAccount.password);
      if (userMatches) {
        account = userAccount;
        accountType = 'user';
      }
    }

    if (!account) {
      throw new AppError('Invalid email or password', 401);
    }

    return this.issueTokenPair(account, accountType);
  }

  async refresh(refreshToken) {
    if (!refreshToken) {
      throw new AppError('Refresh token is required', 400);
    }

    const config = this.getConfig();
    let decoded;

    try {
      decoded = verifyRefreshToken(refreshToken, config);
    } catch {
      throw new AppError('Invalid or expired refresh token', 401);
    }

    const accountType = decoded.accountType || decoded.role;
    let account;

    if (accountType === 'admin') {
      account = await authRepository.findAdminById(decoded.sub, { withSensitive: true });
    } else {
      account = await authRepository.findUserById(decoded.sub, { withSensitive: true });
    }

    if (!account || account.status !== 'active') {
      throw new AppError('Invalid or expired refresh token', 401);
    }

    const tokens = account.refreshTokens || [];
    let matchedIndex = -1;

    for (let i = 0; i < tokens.length; i += 1) {
      const entry = tokens[i];
      if (entry.expiresAt <= new Date()) {
        continue;
      }
      // eslint-disable-next-line no-await-in-loop
      const matches = await compareToken(refreshToken, entry.tokenHash);
      if (matches) {
        matchedIndex = i;
        break;
      }
    }

    if (matchedIndex === -1) {
      throw new AppError('Refresh token has been revoked', 401);
    }

    account.refreshTokens.splice(matchedIndex, 1);
    await authRepository.saveAccount(account);

    return this.issueTokenPair(account, accountType === 'admin' ? 'admin' : 'user');
  }

  async logout(refreshToken, accountId, accountType) {
    if (!accountId || !accountType) {
      throw new AppError('Authentication required', 401);
    }

    let account;
    if (accountType === 'admin') {
      account = await authRepository.findAdminById(accountId, { withSensitive: true });
    } else {
      account = await authRepository.findUserById(accountId, { withSensitive: true });
    }

    if (!account) {
      throw new AppError('Account not found', 404);
    }

    if (!refreshToken) {
      account.refreshTokens = [];
      await authRepository.saveAccount(account);
      return { message: 'Logged out successfully' };
    }

    const remaining = [];
    for (const entry of account.refreshTokens || []) {
      // eslint-disable-next-line no-await-in-loop
      const matches = await compareToken(refreshToken, entry.tokenHash);
      if (!matches) {
        remaining.push(entry);
      }
    }

    account.refreshTokens = remaining;
    await authRepository.saveAccount(account);

    return { message: 'Logged out successfully' };
  }

  async getProfile(accountId, accountType) {
    let account;

    if (accountType === 'admin') {
      account = await authRepository.findAdminById(accountId);
    } else {
      account = await authRepository.findUserById(accountId);
    }

    if (!account) {
      throw new AppError('Account not found', 404);
    }

    if (account.status !== 'active') {
      throw new AppError('Account is not active', 403);
    }

    const profile = account.toSafeObject();
    profile.joinedDate = profile.createdAt;

    if (accountType === 'admin') {
      profile.orderCount = 0;
      profile.totalPurchases = 0;
      return profile;
    }

    const Order = require('../models/Order');
    const [orderCount, spendAgg] = await Promise.all([
      Order.countDocuments({
        user: accountId,
        status: { $nin: ['CANCELLED', 'EXPIRED'] },
      }),
      Order.aggregate([
        {
          $match: {
            user: account._id,
            paymentStatus: 'SUCCESS',
          },
        },
        { $group: { _id: null, total: { $sum: '$grandTotal' } } },
      ]),
    ]);

    profile.orderCount = orderCount;
    profile.totalPurchases = spendAgg[0]?.total || 0;
    return profile;
  }

  /**
   * Development-only admin password reset (no email OTP).
   * Resets password for an existing Admin account and clears refresh tokens.
   */
  async resetAdminPassword({ email, newPassword }) {
    const config = this.getConfig();
    if (config.nodeEnv === 'production') {
      throw new AppError('Admin password reset is disabled in production', 403);
    }

    const normalizedEmail = String(email || '').toLowerCase().trim();
    if (!normalizedEmail) {
      throw new AppError('Email is required', 400);
    }

    const admin = await authRepository.findAdminByEmail(normalizedEmail, {
      withSensitive: true,
    });
    if (!admin) {
      throw new AppError('Admin account not found', 404);
    }

    admin.password = await hashPassword(newPassword, config.bcryptSaltRounds);
    admin.status = 'active';
    admin.refreshTokens = [];
    await authRepository.saveAccount(admin);

    return {
      message: 'Admin password reset successfully',
      email: admin.email,
      role: 'admin',
    };
  }
}

module.exports = new AuthService();
