'use strict';

const express = require('express');
const boxController = require('../controllers/box.controller');
const {
  listBoxesValidator,
  boxIdParamValidator,
  updateBoxValidator,
} = require('../validators/box.validator');
const validate = require('../middlewares/validate');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(authenticate);

router.get(
  '/',
  authorize('user', 'admin'),
  listBoxesValidator,
  validate,
  boxController.listBoxes,
);

router.get(
  '/:id',
  authorize('user', 'admin'),
  boxIdParamValidator,
  validate,
  boxController.getBox,
);

router.put(
  '/:id',
  authorize('admin'),
  updateBoxValidator,
  validate,
  boxController.updateBox,
);

module.exports = router;
