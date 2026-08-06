'use strict';

const express = require('express');
const lockerController = require('../controllers/locker.controller');
const {
  createLockerValidator,
  updateLockerValidator,
  lockerIdParamValidator,
  listLockersValidator,
} = require('../validators/locker.validator');
const validate = require('../middlewares/validate');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(authenticate);

router.get(
  '/',
  authorize('user', 'admin'),
  listLockersValidator,
  validate,
  lockerController.listLockers,
);

router.get(
  '/:id',
  authorize('user', 'admin'),
  lockerIdParamValidator,
  validate,
  lockerController.getLocker,
);

router.post(
  '/',
  authorize('admin'),
  createLockerValidator,
  validate,
  lockerController.createLocker,
);

router.put(
  '/:id',
  authorize('admin'),
  updateLockerValidator,
  validate,
  lockerController.updateLocker,
);

router.delete(
  '/:id',
  authorize('admin'),
  lockerIdParamValidator,
  validate,
  lockerController.deleteLocker,
);

module.exports = router;
