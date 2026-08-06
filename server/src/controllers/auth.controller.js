'use strict';

const authService = require('../services/auth.service');
const asyncHandler = require('../middlewares/asyncHandler');

const REFRESH_COOKIE = 'refreshToken';

function setRefreshCookie(res, refreshToken) {
  res.cookie(REFRESH_COOKIE, refreshToken, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: 7 * 24 * 60 * 60 * 1000,
  });
}

function clearRefreshCookie(res) {
  res.clearCookie(REFRESH_COOKIE, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
  });
}

function getRefreshToken(req) {
  return req.body.refreshToken || req.cookies?.refreshToken;
}

const signup = asyncHandler(async (req, res) => {
  const result = await authService.signup(req.body);
  setRefreshCookie(res, result.refreshToken);

  res.status(201).json({
    success: true,
    message: 'Signup successful',
    data: result,
  });
});

const login = asyncHandler(async (req, res) => {
  const result = await authService.login(req.body);
  setRefreshCookie(res, result.refreshToken);

  res.status(200).json({
    success: true,
    message: 'Login successful',
    data: result,
  });
});

const logout = asyncHandler(async (req, res) => {
  const refreshToken = getRefreshToken(req);
  const result = await authService.logout(
    refreshToken,
    req.auth?.sub,
    req.auth?.accountType || req.auth?.role,
  );

  clearRefreshCookie(res);

  res.status(200).json({
    success: true,
    message: result.message,
  });
});

const refresh = asyncHandler(async (req, res) => {
  const refreshToken = getRefreshToken(req);
  const result = await authService.refresh(refreshToken);
  setRefreshCookie(res, result.refreshToken);

  res.status(200).json({
    success: true,
    message: 'Token refreshed successfully',
    data: result,
  });
});

const profile = asyncHandler(async (req, res) => {
  const user = await authService.getProfile(
    req.auth.sub,
    req.auth.accountType || req.auth.role,
  );

  res.status(200).json({
    success: true,
    message: 'Profile fetched successfully',
    data: { user },
  });
});

const resetAdminPassword = asyncHandler(async (req, res) => {
  const result = await authService.resetAdminPassword(req.body);
  res.status(200).json({
    success: true,
    message: result.message,
    data: result,
  });
});

module.exports = {
  signup,
  login,
  logout,
  refresh,
  profile,
  resetAdminPassword,
};
