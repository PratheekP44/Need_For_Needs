'use strict';

/**
 * Campus Essentials BLE Protocol — Phase 10 design package.
 *
 * This module is a protocol reference only:
 * - No BLE stack
 * - No Flutter
 * - No TI firmware
 * - No Payment / Order API changes
 */

const constants = require('./constants');
const { BlePacket, PayloadSchemas, createPacket } = require('./packetModel');
const checksum = require('./checksum');
const { serializePacket, serializeToHex } = require('./serializer');
const { parsePacket } = require('./parser');
const { SequenceNumberManager } = require('./sequenceManager');
const { RetryPolicy } = require('./retryPolicy');
const { TimeoutPolicy } = require('./timeoutPolicy');
const { BleSessionStateMachine } = require('./stateMachine');
const collectionToken = require('./collectionToken');

module.exports = {
  ...constants,
  BlePacket,
  PayloadSchemas,
  createPacket,
  ...checksum,
  serializePacket,
  serializeToHex,
  parsePacket,
  SequenceNumberManager,
  RetryPolicy,
  TimeoutPolicy,
  BleSessionStateMachine,
  ...collectionToken,
};
