'use strict';

const express = require('express');
const catalogController = require('../controllers/catalog.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(authenticate);

router.get(
  '/home',
  authorize('user', 'admin'),
  catalogController.getHome,
);

router.get(
  '/categories',
  authorize('user', 'admin'),
  catalogController.listCategories,
);

module.exports = router;
