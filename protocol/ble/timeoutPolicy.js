'use strict';

/**
 * Timeout policy for protocol operations (design-time defaults).
 * Values are chosen for campus BLE: short MTU writes, human-scale door open.
 */
class TimeoutPolicy {
  /**
   * @param {object} [options] override any named timeout in ms
   */
  constructor(options = {}) {
    this.connectMs = options.connectMs ?? 8000;
    this.pingMs = options.pingMs ?? 1500;
    this.authMs = options.authMs ?? 3000;
    this.openBoxMs = options.openBoxMs ?? 5000;
    this.statusMs = options.statusMs ?? 2000;
    this.heartbeatIntervalMs = options.heartbeatIntervalMs ?? 5000;
    this.heartbeatMissLimit = options.heartbeatMissLimit ?? 3;
    this.sessionIdleMs = options.sessionIdleMs ?? 90000;
    this.disconnectGraceMs = options.disconnectGraceMs ?? 1000;
  }

  /**
   * Resolve response timeout for a request packet type.
   * @param {string} packetTypeName
   */
  responseTimeoutMs(packetTypeName) {
    switch (packetTypeName) {
      case 'PING':
        return this.pingMs;
      case 'AUTH':
        return this.authMs;
      case 'OPEN_BOX':
        return this.openBoxMs;
      case 'STATUS':
        return this.statusMs;
      case 'HEARTBEAT':
        return this.pingMs;
      default:
        return this.pingMs;
    }
  }

  /** Total wait before declaring BLE_TIMEOUT across retries. */
  budgetMs(packetTypeName, maxAttempts) {
    const perTry = this.responseTimeoutMs(packetTypeName);
    return perTry * Math.max(1, maxAttempts);
  }

  describe() {
    return {
      connectMs: this.connectMs,
      pingMs: this.pingMs,
      authMs: this.authMs,
      openBoxMs: this.openBoxMs,
      statusMs: this.statusMs,
      heartbeatIntervalMs: this.heartbeatIntervalMs,
      heartbeatMissLimit: this.heartbeatMissLimit,
      sessionIdleMs: this.sessionIdleMs,
      disconnectGraceMs: this.disconnectGraceMs,
    };
  }
}

module.exports = {
  TimeoutPolicy,
};
