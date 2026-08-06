'use strict';

const ActivityLog = require('../models/ActivityLog');
const logger = require('../config/logger');

class ActivityService {
  async log({
    action,
    entity,
    entityId,
    userId = null,
    adminId = null,
    metadata = null,
  }) {
    try {
      await ActivityLog.create({
        action,
        entity,
        entityId,
        user: userId,
        admin: adminId,
        metadata,
        timestamp: new Date(),
      });
    } catch (error) {
      // Audit logging must never break primary business flows.
      logger.error('Failed to write activity log', {
        message: error.message,
        action,
        entity,
        entityId: String(entityId),
      });
    }
  }
}

module.exports = new ActivityService();
