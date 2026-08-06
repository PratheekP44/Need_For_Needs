'use strict';

const { SESSION_STATES } = require('./constants');

/**
 * Phone-side BLE collection session state machine (protocol design).
 * Does not perform BLE I/O — only validates transitions.
 *
 * Happy path:
 *   IDLE → CONNECTED → AUTHENTICATED → OPEN_REQUEST → OPENING
 *     → OPEN_SUCCESS → COMPLETE
 */
class BleSessionStateMachine {
  constructor() {
    this.state = SESSION_STATES.IDLE;
    this.history = [{ state: this.state, at: Date.now(), event: 'init' }];
    this.failureReason = null;
  }

  getState() {
    return this.state;
  }

  /**
   * Allowed transitions map.
   * FAILED and COMPLETE are terminal until reset().
   */
  static get transitions() {
    return Object.freeze({
      [SESSION_STATES.IDLE]: ['CONNECTED', 'FAILED'],
      [SESSION_STATES.CONNECTED]: ['AUTHENTICATED', 'FAILED', 'IDLE'],
      [SESSION_STATES.AUTHENTICATED]: ['OPEN_REQUEST', 'FAILED', 'IDLE'],
      [SESSION_STATES.OPEN_REQUEST]: ['OPENING', 'FAILED', 'AUTHENTICATED'],
      [SESSION_STATES.OPENING]: ['OPEN_SUCCESS', 'FAILED', 'OPEN_REQUEST'],
      [SESSION_STATES.OPEN_SUCCESS]: ['COMPLETE', 'FAILED'],
      [SESSION_STATES.COMPLETE]: [],
      [SESSION_STATES.FAILED]: [],
    });
  }

  /**
   * High-level events mapped to transitions.
   */
  static get eventMap() {
    return Object.freeze({
      ble_connected: { from: [SESSION_STATES.IDLE], to: SESSION_STATES.CONNECTED },
      auth_ok: {
        from: [SESSION_STATES.CONNECTED],
        to: SESSION_STATES.AUTHENTICATED,
      },
      open_requested: {
        from: [SESSION_STATES.AUTHENTICATED],
        to: SESSION_STATES.OPEN_REQUEST,
      },
      open_sent: {
        from: [SESSION_STATES.OPEN_REQUEST],
        to: SESSION_STATES.OPENING,
      },
      open_ack_ok: {
        from: [SESSION_STATES.OPENING],
        to: SESSION_STATES.OPEN_SUCCESS,
      },
      collection_done: {
        from: [SESSION_STATES.OPEN_SUCCESS],
        to: SESSION_STATES.COMPLETE,
      },
      retry_open: {
        from: [SESSION_STATES.OPENING, SESSION_STATES.OPEN_REQUEST],
        to: SESSION_STATES.OPEN_REQUEST,
      },
      disconnect: {
        from: [
          SESSION_STATES.CONNECTED,
          SESSION_STATES.AUTHENTICATED,
          SESSION_STATES.OPEN_REQUEST,
          SESSION_STATES.OPENING,
        ],
        to: SESSION_STATES.IDLE,
      },
      fail: {
        from: Object.values(SESSION_STATES).filter(
          (s) => s !== SESSION_STATES.COMPLETE && s !== SESSION_STATES.FAILED,
        ),
        to: SESSION_STATES.FAILED,
      },
    });
  }

  canTransition(nextState) {
    const allowed = BleSessionStateMachine.transitions[this.state] || [];
    return allowed.includes(nextState);
  }

  transition(nextState, event = 'manual') {
    if (!this.canTransition(nextState)) {
      const err = new Error(
        `Illegal transition ${this.state} → ${nextState} (event=${event})`,
      );
      err.code = 'ILLEGAL_TRANSITION';
      throw err;
    }
    this.state = nextState;
    this.history.push({ state: this.state, at: Date.now(), event });
    return this.state;
  }

  handle(eventName, detail = {}) {
    const mapping = BleSessionStateMachine.eventMap[eventName];
    if (!mapping) {
      throw new Error(`Unknown event: ${eventName}`);
    }
    if (!mapping.from.includes(this.state)) {
      const err = new Error(
        `Event ${eventName} not valid in state ${this.state}`,
      );
      err.code = 'INVALID_EVENT';
      throw err;
    }
    if (eventName === 'fail') {
      this.failureReason = detail.reason || 'unspecified';
    }
    return this.transition(mapping.to, eventName);
  }

  reset() {
    this.state = SESSION_STATES.IDLE;
    this.failureReason = null;
    this.history = [{ state: this.state, at: Date.now(), event: 'reset' }];
  }

  describe() {
    return {
      state: this.state,
      failureReason: this.failureReason,
      history: [...this.history],
      transitions: BleSessionStateMachine.transitions,
    };
  }
}

module.exports = {
  BleSessionStateMachine,
  SESSION_STATES,
};
