'use strict';

const express = require('express');
const healthRoutes = require('./health.routes');
const authRoutes = require('./auth.routes');
const lockerRoutes = require('./locker.routes');
const boxRoutes = require('./box.routes');
const itemRoutes = require('./item.routes');
const stockRoutes = require('./stock.routes');
const cartRoutes = require('./cart.routes');
const orderRoutes = require('./order.routes');
const { paymentRouter, paymentsRouter } = require('./payment.routes');

const router = express.Router();

router.use('/health', healthRoutes);
router.use('/auth', authRoutes);
router.use('/lockers', lockerRoutes);
router.use('/boxes', boxRoutes);
router.use('/items', itemRoutes);
router.use('/stock', stockRoutes);
router.use('/catalog', require('./catalog.routes'));
router.use('/admin', require('./admin.routes'));
router.use('/cart', cartRoutes);
router.use(orderRoutes);
router.use('/payment', paymentRouter);
router.use('/payments', paymentsRouter);
router.use('/events', require('./events.routes'));

module.exports = router;
