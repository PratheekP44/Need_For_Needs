'use strict';

const {
  PROTOCOL_VERSION,
  LIMITS,
  PACKET_TYPES,
  PACKET_TYPE_NAMES,
  ERROR_CODES,
} = require('./constants');

/**
 * Canonical BLE protocol packet model (design-time).
 * Every on-air frame maps to this shape.
 */
class BlePacket {
  /**
   * @param {object} fields
   */
  constructor(fields = {}) {
    this.protocolVersion = fields.protocolVersion ?? PROTOCOL_VERSION;
    this.packetType = fields.packetType;
    this.sequenceNumber = fields.sequenceNumber ?? 0;
    this.timestamp = fields.timestamp ?? Math.floor(Date.now() / 1000);
    this.orderId = fields.orderId ?? '';
    this.lockerId = fields.lockerId ?? '';
    this.boxId = fields.boxId ?? '';
    this.collectionToken = fields.collectionToken ?? '';
    this.payloadLength =
      fields.payloadLength ??
      (Buffer.isBuffer(fields.payload)
        ? fields.payload.length
        : Buffer.byteLength(fields.payload || '', 'utf8'));
    this.payload = fields.payload ?? Buffer.alloc(0);
    this.checksum = fields.checksum ?? 0;
  }

  get packetTypeName() {
    if (typeof this.packetType === 'string') return this.packetType;
    return PACKET_TYPE_NAMES[this.packetType] || 'UNKNOWN';
  }

  get packetTypeCode() {
    if (typeof this.packetType === 'number') return this.packetType;
    return PACKET_TYPES[this.packetType];
  }

  /**
   * Normalize payload to Buffer for framing.
   */
  payloadBuffer() {
    if (Buffer.isBuffer(this.payload)) return this.payload;
    if (this.payload == null) return Buffer.alloc(0);
    if (typeof this.payload === 'object') {
      return Buffer.from(JSON.stringify(this.payload), 'utf8');
    }
    return Buffer.from(String(this.payload), 'utf8');
  }

  toJSON() {
    const payloadBuf = this.payloadBuffer();
    let payloadPreview;
    try {
      payloadPreview = JSON.parse(payloadBuf.toString('utf8'));
    } catch {
      payloadPreview = payloadBuf.toString('hex');
    }

    return {
      protocolVersion: this.protocolVersion,
      packetType: this.packetTypeName,
      packetTypeCode: this.packetTypeCode,
      sequenceNumber: this.sequenceNumber,
      timestamp: this.timestamp,
      orderId: this.orderId,
      lockerId: this.lockerId,
      boxId: this.boxId,
      collectionToken: this.collectionToken,
      payloadLength: payloadBuf.length,
      payload: payloadPreview,
      checksum: this.checksum,
    };
  }

  /**
   * Structural validation (not cryptographic).
   * @returns {{ ok: boolean, errors: string[] }}
   */
  validate() {
    const errors = [];

    if (this.protocolVersion !== PROTOCOL_VERSION) {
      errors.push(`Unsupported protocolVersion: ${this.protocolVersion}`);
    }

    const typeCode = this.packetTypeCode;
    if (typeCode == null || PACKET_TYPE_NAMES[typeCode] == null) {
      errors.push(`Unknown packetType: ${this.packetType}`);
    }

    if (!Number.isInteger(this.sequenceNumber) || this.sequenceNumber < 0 || this.sequenceNumber > 0xffff) {
      errors.push('sequenceNumber must be uint16');
    }

    if (!Number.isInteger(this.timestamp) || this.timestamp < 0) {
      errors.push('timestamp must be non-negative unix seconds');
    }

    const checks = [
      ['orderId', LIMITS.orderId],
      ['lockerId', LIMITS.lockerId],
      ['boxId', LIMITS.boxId],
      ['collectionToken', LIMITS.collectionToken],
    ];
    for (const [field, max] of checks) {
      const value = String(this[field] ?? '');
      const len = Buffer.byteLength(value, 'utf8');
      if (len > max) errors.push(`${field} exceeds ${max} bytes`);
    }

    const payloadBuf = this.payloadBuffer();
    if (payloadBuf.length > LIMITS.payload) {
      errors.push(`payload exceeds ${LIMITS.payload} bytes`);
    }
    if (this.payloadLength !== payloadBuf.length) {
      errors.push('payloadLength does not match payload byte length');
    }

    return { ok: errors.length === 0, errors };
  }
}

/**
 * Typed payload helpers (JSON inside payload bytes).
 */
const PayloadSchemas = {
  empty() {
    return Buffer.alloc(0);
  },

  auth({ tokenIssuedAt, tokenExpiresAt, phoneNonce } = {}) {
    return Buffer.from(
      JSON.stringify({
        tokenIssuedAt: tokenIssuedAt ?? null,
        tokenExpiresAt: tokenExpiresAt ?? null,
        phoneNonce: phoneNonce ?? null,
      }),
      'utf8',
    );
  },

  authAck({ accepted, sessionTtlSeconds, firmwareVersion } = {}) {
    return Buffer.from(
      JSON.stringify({
        accepted: Boolean(accepted),
        sessionTtlSeconds: sessionTtlSeconds ?? 120,
        firmwareVersion: firmwareVersion ?? 'unknown',
      }),
      'utf8',
    );
  },

  openBox({ reason } = {}) {
    return Buffer.from(
      JSON.stringify({
        reason: reason || 'collection',
      }),
      'utf8',
    );
  },

  openAck({ opened, doorState, boxStatus } = {}) {
    return Buffer.from(
      JSON.stringify({
        opened: Boolean(opened),
        doorState: doorState || 'UNKNOWN',
        boxStatus: boxStatus || 'UNKNOWN',
      }),
      'utf8',
    );
  },

  statusRequest({ includeDoor } = {}) {
    return Buffer.from(
      JSON.stringify({
        includeDoor: includeDoor !== false,
      }),
      'utf8',
    );
  },

  statusResponse({ doorState, boxStatus, batteryMv, uptimeSeconds } = {}) {
    return Buffer.from(
      JSON.stringify({
        doorState: doorState || 'UNKNOWN',
        boxStatus: boxStatus || 'UNKNOWN',
        batteryMv: batteryMv ?? null,
        uptimeSeconds: uptimeSeconds ?? null,
      }),
      'utf8',
    );
  },

  error({ code, message, retryable } = {}) {
    const numeric =
      typeof code === 'string' ? ERROR_CODES[code] : code;
    return Buffer.from(
      JSON.stringify({
        code: numeric,
        name:
          typeof code === 'string'
            ? code
            : Object.keys(ERROR_CODES).find((k) => ERROR_CODES[k] === numeric) ||
              'UNKNOWN',
        message: message || '',
        retryable: Boolean(retryable),
      }),
      'utf8',
    );
  },

  heartbeat({ rssi } = {}) {
    return Buffer.from(JSON.stringify({ rssi: rssi ?? null }), 'utf8');
  },
};

function createPacket(packetType, fields = {}) {
  const payload = fields.payload ?? Buffer.alloc(0);
  const packet = new BlePacket({
    ...fields,
    packetType,
    payload,
    payloadLength: Buffer.isBuffer(payload)
      ? payload.length
      : Buffer.byteLength(payload || '', 'utf8'),
  });
  return packet;
}

module.exports = {
  BlePacket,
  PayloadSchemas,
  createPacket,
};
