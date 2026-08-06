'use strict';

const AppError = require('../utils/AppError');
const { verifyAccessToken } = require('../utils/token');
const { loadEnv } = require('../config/env');
const authRepository = require('../repositories/auth.repository');

/**
 * Verifies Bearer JWT access token and attaches req.auth / req.user.
 */
async function authenticate(req, res, next) {
  try {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      throw new AppError('Authentication required', 401);
    }

    const token = header.slice(7).trim();
    if (!token) {
      throw new AppError('Authentication required', 401);
    }

    const config = loadEnv();
    let decoded;

    try {
      decoded = verifyAccessToken(token, config);
    } catch {
      throw new AppError('Invalid or expired access token', 401);
    }

    const accountType = decoded.accountType || decoded.role;
    let account;

    if (accountType === 'admin') {
      account = await authRepository.findAdminById(decoded.sub);
    } else {
      account = await authRepository.findUserById(decoded.sub);
    }

    if (!account) {
      throw new AppError('Account not found', 401);
    }

    if (account.status !== 'active') {
      throw new AppError('Account is not active', 403);
    }

    req.auth = {
      sub: String(account._id),
      email: account.email,
      role: accountType === 'admin' ? 'admin' : 'user',
      accountType: accountType === 'admin' ? 'admin' : 'user',
    };
    req.user = account.toSafeObject();

    return next();
  } catch (error) {
    return next(error);
  }
}

/**
 * Role-based authorization. Usage: authorize('admin') or authorize('user', 'admin')
 */
function authorize(...allowedRoles) {
  return (req, res, next) => {
    if (!req.auth) {
      return next(new AppError('Authentication required', 401));
    }

    if (!allowedRoles.includes(req.auth.role)) {
      return next(new AppError('Forbidden: insufficient role', 403));
    }

    return next();
  };
}

module.exports = {
  authenticate,
  authorize,
};
