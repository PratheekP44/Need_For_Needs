'use strict';

/**
 * Campus Essentials BLE Protocol — Phase 10
 * Design-only constants. No radio / GATT / firmware I/O.
 */

const PROTOCOL_NAME = 'CampusEssentialsBLE';
const PROTOCOL_VERSION = 1;

/** Maximum field sizes (bytes) for TI CC2340-friendly framing. */
const LIMITS = Object.freeze({
  orderId: 40,
  lockerId: 32,
  boxId: 32,
  collectionToken: 128,
  payload: 200,
  /** Soft max total frame size (header + fields + checksum). */
  maxFrameBytes: 512,
});

/**
 * Packet type codes (uint8).
 * Values are spaced by category for firmware readability.
 */
const PACKET_TYPES = Object.freeze({
  PING: 0x01,
  PONG: 0x02,
  AUTH: 0x10,
  AUTH_ACK: 0x11,
  OPEN_BOX: 0x20,
  OPEN_ACK: 0x21,
  STATUS: 0x30,
  STATUS_RESPONSE: 0x31,
  ERROR: 0x40,
  HEARTBEAT: 0x50,
  DISCONNECT: 0x60,
});

const PACKET_TYPE_NAMES = Object.freeze(
  Object.fromEntries(
    Object.entries(PACKET_TYPES).map(([name, code]) => [code, name]),
  ),
);

/** Application error codes carried inside ERROR payloads. */
const ERROR_CODES = Object.freeze({
  INVALID_TOKEN: 1001,
  INVALID_BOX: 1002,
  LOCKER_BUSY: 1003,
  DOOR_ALREADY_OPEN: 1004,
  BLE_TIMEOUT: 1005,
  UNKNOWN_COMMAND: 1006,
  CRC_FAILED: 1007,
});

const ERROR_CODE_NAMES = Object.freeze(
  Object.fromEntries(
    Object.entries(ERROR_CODES).map(([name, code]) => [code, name]),
  ),
);

/** Session / open-door state machine states (phone-side protocol view). */
const SESSION_STATES = Object.freeze({
  IDLE: 'IDLE',
  CONNECTED: 'CONNECTED',
  AUTHENTICATED: 'AUTHENTICATED',
  OPEN_REQUEST: 'OPEN_REQUEST',
  OPENING: 'OPENING',
  OPEN_SUCCESS: 'OPEN_SUCCESS',
  COMPLETE: 'COMPLETE',
  FAILED: 'FAILED',
});

/** Direction hints for documentation and tooling. */
const DIRECTIONS = Object.freeze({
  PHONE_TO_LOCKER: 'PHONE_TO_LOCKER',
  LOCKER_TO_PHONE: 'LOCKER_TO_PHONE',
  BIDIRECTIONAL: 'BIDIRECTIONAL',
});

const PACKET_TYPE_META = Object.freeze({
  PING: { direction: DIRECTIONS.PHONE_TO_LOCKER, expects: 'PONG' },
  PONG: { direction: DIRECTIONS.LOCKER_TO_PHONE, expects: null },
  AUTH: { direction: DIRECTIONS.PHONE_TO_LOCKER, expects: 'AUTH_ACK' },
  AUTH_ACK: { direction: DIRECTIONS.LOCKER_TO_PHONE, expects: null },
  OPEN_BOX: { direction: DIRECTIONS.PHONE_TO_LOCKER, expects: 'OPEN_ACK' },
  OPEN_ACK: { direction: DIRECTIONS.LOCKER_TO_PHONE, expects: null },
  STATUS: { direction: DIRECTIONS.PHONE_TO_LOCKER, expects: 'STATUS_RESPONSE' },
  STATUS_RESPONSE: { direction: DIRECTIONS.LOCKER_TO_PHONE, expects: null },
  ERROR: { direction: DIRECTIONS.BIDIRECTIONAL, expects: null },
  HEARTBEAT: { direction: DIRECTIONS.BIDIRECTIONAL, expects: null },
  DISCONNECT: { direction: DIRECTIONS.BIDIRECTIONAL, expects: null },
});

module.exports = {
  PROTOCOL_NAME,
  PROTOCOL_VERSION,
  LIMITS,
  PACKET_TYPES,
  PACKET_TYPE_NAMES,
  ERROR_CODES,
  ERROR_CODE_NAMES,
  SESSION_STATES,
  DIRECTIONS,
  PACKET_TYPE_META,
};
