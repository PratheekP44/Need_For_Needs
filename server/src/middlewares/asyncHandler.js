'use strict';

/**
 * Wraps async route handlers so rejected promises reach the global error handler.
 */
function asyncHandler(fn) {
  return function wrappedAsyncHandler(req, res, next) {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

module.exports = asyncHandler;
