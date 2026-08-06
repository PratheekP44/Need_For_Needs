'use strict';

const bcrypt = require('bcrypt');

async function hashPassword(plainPassword, saltRounds) {
  return bcrypt.hash(plainPassword, saltRounds);
}

async function comparePassword(plainPassword, passwordHash) {
  return bcrypt.compare(plainPassword, passwordHash);
}

async function hashToken(token, saltRounds = 10) {
  return bcrypt.hash(token, saltRounds);
}

async function compareToken(token, tokenHash) {
  return bcrypt.compare(token, tokenHash);
}

module.exports = {
  hashPassword,
  comparePassword,
  hashToken,
  compareToken,
};
