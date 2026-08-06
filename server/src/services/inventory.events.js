'use strict';

const { EventEmitter } = require('events');

/**
 * In-process inventory / catalog change bus.
 * SSE clients subscribe; payment verify publishes after stock assignment.
 */
class InventoryEvents extends EventEmitter {
  constructor() {
    super();
    this.setMaxListeners(100);
  }

  /**
   * @param {{ reason: string, orderNumber?: string, stockIds?: string[], at?: Date }} payload
   */
  publish(payload = {}) {
    const event = {
      type: 'inventory_updated',
      reason: payload.reason || 'update',
      orderNumber: payload.orderNumber || null,
      stockIds: payload.stockIds || [],
      at: (payload.at || new Date()).toISOString(),
    };
    this.emit('inventory', event);
    return event;
  }
}

module.exports = new InventoryEvents();
