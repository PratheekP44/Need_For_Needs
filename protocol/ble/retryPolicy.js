'use strict';

/**
 * Retry policy for request/response packet pairs (design-time).
 * No timers are started here — callers apply delays using timeoutPolicy.
 */
class RetryPolicy {
  /**
   * @param {object} [options]
   * @param {number} [options.maxAttempts=3]
   * @param {number} [options.baseDelayMs=400]
   * @param {number} [options.maxDelayMs=3000]
   * @param {number} [options.jitterRatio=0.2]
   * @param {string[]} [options.retryablePacketTypes]
   * @param {number[]} [options.retryableErrorCodes]
   */
  constructor(options = {}) {
    this.maxAttempts = options.maxAttempts ?? 3;
    this.baseDelayMs = options.baseDelayMs ?? 400;
    this.maxDelayMs = options.maxDelayMs ?? 3000;
    this.jitterRatio = options.jitterRatio ?? 0.2;
    this.retryablePacketTypes = new Set(
      options.retryablePacketTypes || [
        'PING',
        'AUTH',
        'OPEN_BOX',
        'STATUS',
        'HEARTBEAT',
      ],
    );
    this.retryableErrorCodes = new Set(
      options.retryableErrorCodes || [
        1003, // LOCKER_BUSY
        1005, // BLE_TIMEOUT
      ],
    );
  }

  shouldRetry({ attempt, packetType, errorCode, fatal } = {}) {
    if (fatal) return false;
    if (attempt >= this.maxAttempts) return false;
    if (packetType && !this.retryablePacketTypes.has(packetType)) return false;
    if (errorCode != null && !this.retryableErrorCodes.has(errorCode)) {
      // Non-listed application errors are not retried (e.g. INVALID_TOKEN).
      if (
        [
          1001, // INVALID_TOKEN
          1002, // INVALID_BOX
          1004, // DOOR_ALREADY_OPEN
          1006, // UNKNOWN_COMMAND
          1007, // CRC_FAILED — re-send once may help; allow if in set
        ].includes(errorCode) &&
        !this.retryableErrorCodes.has(errorCode)
      ) {
        return false;
      }
    }
    return true;
  }

  /**
   * Exponential backoff with jitter.
   * attempt is 1-based for the next try after a failure.
   */
  delayMs(attempt) {
    const exp = Math.min(
      this.maxDelayMs,
      this.baseDelayMs * 2 ** Math.max(0, attempt - 1),
    );
    const jitter = exp * this.jitterRatio * Math.random();
    return Math.round(Math.min(this.maxDelayMs, exp + jitter));
  }

  describe() {
    return {
      maxAttempts: this.maxAttempts,
      baseDelayMs: this.baseDelayMs,
      maxDelayMs: this.maxDelayMs,
      jitterRatio: this.jitterRatio,
      retryablePacketTypes: [...this.retryablePacketTypes],
      retryableErrorCodes: [...this.retryableErrorCodes],
    };
  }
}

module.exports = {
  RetryPolicy,
};
