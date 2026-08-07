import 'dart:typed_data';

import '../models/packet.dart';
import '../transport/ble_log.dart';
import 'packet_codec.dart';
import 'packet_types.dart';
import 'parsed_ble_response.dart';

/// Parses notify-characteristic payloads into [ParsedBleResponse].
///
/// Handles full Phase 10 frames and short / unknown status blobs so the
/// Collect UI never depends on raw bytes.
class PacketParser {
  PacketParser({PacketCodec? codec}) : _codec = codec ?? const PacketCodec();

  final PacketCodec _codec;

  /// Classify an already-decoded [Packet] without re-logging as a fresh RX.
  ParsedBleResponse parsePacket(Packet packet) {
    final raw = _codec.encode(packet);
    final hex = _hex(raw);
    return _fromPacket(packet, raw, hex);
  }

  /// Decode raw notification bytes.
  ParsedBleResponse parse(Uint8List raw) {
    final hex = _hex(raw);
    BleLog.d('Packet Received (HEX) length=${raw.length} HEX=$hex');

    if (raw.isEmpty) {
      final parsed = ParsedBleResponse(
        kind: BleResponseKind.unknown,
        raw: raw,
        rawHex: hex,
        message: 'Empty notification',
      );
      BleLog.d('Decoded Response: $parsed');
      return parsed;
    }

    // Prefer full Phase 10 frame decode.
    try {
      final packet = _codec.decode(raw);
      final parsed = _fromPacket(packet, raw, hex);
      BleLog.d('Decoded Response: $parsed');
      return parsed;
    } catch (e) {
      BleLog.d('Phase10 decode failed ($e) — trying short status');
    }

    final short = _parseShortStatus(raw, hex);
    BleLog.d('Decoded Response: $short');
    return short;
  }

  ParsedBleResponse _fromPacket(Packet packet, Uint8List raw, String hex) {
    final map = packet.payload.asJsonMap() ?? const <String, Object?>{};
    final seq = packet.header.sequenceNumber;

    switch (packet.packetType) {
      case BlePacketType.pong:
      case BlePacketType.ping:
      case BlePacketType.heartbeat:
        return ParsedBleResponse(
          kind: BleResponseKind.pingPong,
          raw: raw,
          rawHex: hex,
          packet: packet,
          sequenceNumber: seq,
          message: packet.packetType.wireName,
        );

      case BlePacketType.authAck:
        final accepted = map['accepted'] == true;
        return ParsedBleResponse(
          kind: accepted
              ? BleResponseKind.authAccepted
              : BleResponseKind.authRejected,
          raw: raw,
          rawHex: hex,
          packet: packet,
          sequenceNumber: seq,
          accepted: accepted,
          message: accepted ? 'AUTH_ACK' : 'AUTH rejected',
        );

      case BlePacketType.openAck:
        final opened = map['opened'] == true;
        final door = map['doorState']?.toString();
        final box = map['boxStatus']?.toString();
        return ParsedBleResponse(
          kind: opened
              ? BleResponseKind.unlockSuccess
              : BleResponseKind.unlockFailure,
          raw: raw,
          rawHex: hex,
          packet: packet,
          sequenceNumber: seq,
          opened: opened,
          doorState: door,
          boxStatus: box,
          message: opened ? 'Unlock Success' : 'Unlock Failure',
        );

      case BlePacketType.statusResponse:
        final door = map['doorState']?.toString();
        final battery = map['batteryMv'];
        final kind = battery is int
            ? BleResponseKind.batteryStatus
            : BleResponseKind.doorStatus;
        return ParsedBleResponse(
          kind: kind,
          raw: raw,
          rawHex: hex,
          packet: packet,
          sequenceNumber: seq,
          doorState: door,
          boxStatus: map['boxStatus']?.toString(),
          batteryMv: battery is int ? battery : null,
          message: 'STATUS_RESPONSE',
        );

      case BlePacketType.error:
        final codeNum = map['code'];
        final code = codeNum is int ? BleErrorCode.fromCode(codeNum) : null;
        return ParsedBleResponse(
          kind: BleResponseKind.error,
          raw: raw,
          rawHex: hex,
          packet: packet,
          sequenceNumber: seq,
          errorCode: code,
          message: map['message']?.toString() ??
              code?.wireName ??
              'ERROR packet',
        );

      case BlePacketType.auth:
      case BlePacketType.openBox:
      case BlePacketType.status:
      case BlePacketType.disconnect:
        return ParsedBleResponse(
          kind: BleResponseKind.ack,
          raw: raw,
          rawHex: hex,
          packet: packet,
          sequenceNumber: seq,
          message: 'Unexpected inbound ${packet.packetType.wireName}',
        );
    }
  }

  /// Compact ≤16 B notify fallback used when firmware cannot emit full frames
  /// on Char 4. Layout (assumption — document in Phase 14 report):
  ///   [0] type code (0x11 AUTH_ACK, 0x21 OPEN_ACK, 0x31 STATUS, 0x40 ERROR)
  ///   [1] flags bit0=accepted/opened, bit1=nack
  ///   [2..3] sequence BE
  ///   [4] door enum (0 UNKNOWN, 1 CLOSED, 2 OPEN, 3 FAULT)
  ///   [5] battery % or 0xFF
  ///   remainder reserved
  ParsedBleResponse _parseShortStatus(Uint8List raw, String hex) {
    if (raw.length < 2) {
      return ParsedBleResponse(
        kind: BleResponseKind.unknown,
        raw: raw,
        rawHex: hex,
        message: 'Unknown Packet (too short)',
      );
    }

    final type = raw[0];
    final flags = raw[1];
    final nack = (flags & 0x02) != 0;
    final ok = (flags & 0x01) != 0;
    int? seq;
    if (raw.length >= 4) {
      seq = (raw[2] << 8) | raw[3];
    }
    String? door;
    if (raw.length >= 5) {
      door = switch (raw[4]) {
        1 => 'CLOSED',
        2 => 'OPEN',
        3 => 'FAULT',
        _ => 'UNKNOWN',
      };
    }
    int? battery;
    if (raw.length >= 6 && raw[5] != 0xFF) {
      battery = raw[5];
    }

    if (nack) {
      return ParsedBleResponse(
        kind: BleResponseKind.nack,
        raw: raw,
        rawHex: hex,
        sequenceNumber: seq,
        doorState: door,
        batteryMv: battery,
        message: 'NACK',
      );
    }

    switch (type) {
      case 0x11:
        return ParsedBleResponse(
          kind: ok
              ? BleResponseKind.authAccepted
              : BleResponseKind.authRejected,
          raw: raw,
          rawHex: hex,
          sequenceNumber: seq,
          accepted: ok,
          message: ok ? 'AUTH_ACK (short)' : 'AUTH rejected (short)',
        );
      case 0x21:
        return ParsedBleResponse(
          kind: ok
              ? BleResponseKind.unlockSuccess
              : BleResponseKind.unlockFailure,
          raw: raw,
          rawHex: hex,
          sequenceNumber: seq,
          opened: ok,
          doorState: door,
          message: ok ? 'Unlock Success (short)' : 'Unlock Failure (short)',
        );
      case 0x31:
        return ParsedBleResponse(
          kind: battery != null
              ? BleResponseKind.batteryStatus
              : BleResponseKind.doorStatus,
          raw: raw,
          rawHex: hex,
          sequenceNumber: seq,
          doorState: door,
          batteryMv: battery,
          message: 'Status (short)',
        );
      case 0x40:
        return ParsedBleResponse(
          kind: BleResponseKind.error,
          raw: raw,
          rawHex: hex,
          sequenceNumber: seq,
          message: 'ERROR (short)',
        );
      default:
        return ParsedBleResponse(
          kind: BleResponseKind.unknown,
          raw: raw,
          rawHex: hex,
          sequenceNumber: seq,
          doorState: door,
          batteryMv: battery,
          message: 'Unknown Packet type=0x${type.toRadixString(16)}',
        );
    }
  }

  static String _hex(Uint8List bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join(' ');
}
