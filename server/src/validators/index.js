'use strict';

const {
  body,
  param,
  query,
  validationResult,
} = require('express-validator');
const authValidators = require('./auth.validator');

function collectValidationErrors(req) {
  return validationResult(req);
}

module.exports = {
  body,
  param,
  query,
  validationResult,
  collectValidationErrors,
  ...authValidators,
};
