'use strict';

const crypto = require('crypto');
const jwt = require('jsonwebtoken');

function signAccessToken(payload, config) {
  return jwt.sign(payload, config.jwtAccessSecret, {
    expiresIn: config.jwtAccessExpiresIn,
  });
}

function signRefreshToken(payload, config) {
  return jwt.sign(payload, config.jwtRefreshSecret, {
    expiresIn: config.jwtRefreshExpiresIn,
  });
}

function verifyAccessToken(token, config) {
  return jwt.verify(token, config.jwtAccessSecret);
}

function verifyRefreshToken(token, config) {
  return jwt.verify(token, config.jwtRefreshSecret);
}

function createTokenId() {
  return crypto.randomUUID();
}

function getExpiryDate(expiresIn) {
  const match = /^(\d+)([smhd])$/.exec(String(expiresIn).trim());
  if (!match) {
    return new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  }

  const amount = Number(match[1]);
  const unit = match[2];
  const multipliers = {
    s: 1000,
    m: 60 * 1000,
    h: 60 * 60 * 1000,
    d: 24 * 60 * 60 * 1000,
  };

  return new Date(Date.now() + amount * multipliers[unit]);
}

module.exports = {
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  createTokenId,
  getExpiryDate,
};
