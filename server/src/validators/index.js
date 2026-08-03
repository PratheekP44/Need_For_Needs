'use strict';

/**
 * express-validator is installed and ready for later phase validators.
 * No request validation rules are defined in the architecture phase.
 */
const {
  body,
  param,
  query,
  validationResult,
} = require('express-validator');

function collectValidationErrors(req) {
  return validationResult(req);
}

module.exports = {
  body,
  param,
  query,
  validationResult,
  collectValidationErrors,
};
