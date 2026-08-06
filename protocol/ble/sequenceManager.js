'use strict';

/**
 * Sequence number manager (uint16, wraps at 65535).
 * Phone and locker each maintain independent outbound counters.
 */
class SequenceNumberManager {
  /**
   * @param {object} [options]
   * @param {number} [options.initial=1] starting outbound sequence (0 reserved)
   * @param {number} [options.window=32] max in-flight / duplicate detection window
   */
  constructor(options = {}) {
    this.nextOutbound = options.initial ?? 1;
    this.window = options.window ?? 32;
    /** @type {Set<number>} */
    this.recentInbound = new Set();
    this.lastInbound = null;
  }

  /** Allocate next outbound sequence number. */
  next() {
    const value = this.nextOutbound & 0xffff;
    this.nextOutbound = (this.nextOutbound + 1) & 0xffff;
    if (this.nextOutbound === 0) {
      // Skip 0 after wrap — keep 0 reserved for "unset" in tooling.
      this.nextOutbound = 1;
    }
    return value;
  }

  /**
   * Record an inbound sequence. Detects naive duplicates within window.
   * @returns {{ accepted: boolean, duplicate: boolean }}
   */
  acceptInbound(sequenceNumber) {
    const seq = sequenceNumber & 0xffff;
    if (this.recentInbound.has(seq)) {
      return { accepted: false, duplicate: true };
    }

    this.recentInbound.add(seq);
    this.lastInbound = seq;

    if (this.recentInbound.size > this.window) {
      // Drop arbitrary oldest-ish entry (Set iteration order).
      const first = this.recentInbound.values().next().value;
      this.recentInbound.delete(first);
    }

    return { accepted: true, duplicate: false };
  }

  reset() {
    this.nextOutbound = 1;
    this.recentInbound.clear();
    this.lastInbound = null;
  }
}

module.exports = {
  SequenceNumberManager,
};
