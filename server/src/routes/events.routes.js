'use strict';

const express = require('express');
const inventoryEvents = require('../services/inventory.events');
const { authenticate } = require('../middlewares/auth.middleware');

const router = express.Router();

/**
 * Server-Sent Events stream for inventory / catalog updates.
 * Authenticated clients (customer + admin) subscribe; no request body.
 */
router.get('/inventory', authenticate, (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();

  const send = (event) => {
    res.write(`event: inventory\n`);
    res.write(`data: ${JSON.stringify(event)}\n\n`);
  };

  // Initial hello so clients know the stream is live.
  send({
    type: 'connected',
    at: new Date().toISOString(),
  });

  const onInventory = (event) => send(event);
  inventoryEvents.on('inventory', onInventory);

  const heartbeat = setInterval(() => {
    res.write(`: ping\n\n`);
  }, 25000);

  req.on('close', () => {
    clearInterval(heartbeat);
    inventoryEvents.off('inventory', onInventory);
  });
});

module.exports = router;
