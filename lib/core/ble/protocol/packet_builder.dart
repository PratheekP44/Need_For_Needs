import 'dart:convert';
import 'dart:typed_data';

import '../managers/sequence_manager.dart';
import '../models/packet.dart';
import '../models/packet_payload.dart';
import '../transport/ble_log.dart';
import 'packet_codec.dart';
import 'packet_types.dart';
import 'parsed_ble_response.dart';

/// Builds Phase 10 BLE frames as [Uint8List].
///
/// Fixed header layout (do not overwrite without protocol bump):
/// ```
/// Byte[0]     protocolVersion
/// Byte[1]     packetType
/// Byte[2..3]  sequenceNumber (u16 BE)  ← reserved; NOT available for port
/// Byte[4..7]  timestamp (u32 BE)
/// … length-prefixed strings …
/// … payloadLength + JSON payload …
/// ```
///
/// Firmware `port` (box number) is carried in the JSON payload as `"port": N`
/// because bytes 2 and 3 are already the sequence number.
class PacketBuilder {
  PacketBuilder({
    PacketCodec? codec,
    SequenceManager? sequence,
  })  : _codec = codec ?? const PacketCodec(),
        _sequence = sequence ?? SequenceManager();

  final PacketCodec _codec;
  final SequenceManager _sequence;

  SequenceManager get sequence => _sequence;

  /// Allocate next frame counter (uint16, 0 reserved).
  int nextFrameCounter() => _sequence.next();

  /// Build an AUTH packet for collection unlock.
  Uint8List buildAuth(UnlockPacketRequest request) {
    final frameCounter = request.frameCounter ?? nextFrameCounter();
    final timestamp = request.timestamp ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final authMap = <String, Object?>{
      'tokenExpiresAt': request.tokenExpiresAt,
      'phoneNonce': request.phoneNonce ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'transactionId': request.transactionId,
      'port': request.port,
      if (request.bluetoothAddress != null)
        'bluetoothAddress': request.bluetoothAddress,
      if (request.advertisementId != null)
        'advertisementId': request.advertisementId,
      if (request.encryptionKeyId != null)
        'encryptionKeyId': request.encryptionKeyId,
      'encryption': null,
      ...?request.authPayload,
    };

    final packet = Packet.build(
      type: BlePacketType.auth,
      sequenceNumber: frameCounter,
      timestamp: timestamp,
      orderId: request.orderId,
      lockerId: request.lockerId,
      boxId: request.effectivePortId,
      collectionToken: request.collectionToken,
      payload: PacketPayload.json(authMap),
    );

    return _encodeLogged(packet, label: 'AUTH', request: request);
  }

  /// Build an OPEN_BOX (unlock) packet — includes firmware `port`.
  Uint8List buildUnlock(UnlockPacketRequest request) {
    final frameCounter = request.frameCounter ?? nextFrameCounter();
    final timestamp = request.timestamp ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final packet = Packet.build(
      type: BlePacketType.openBox,
      sequenceNumber: frameCounter,
      timestamp: timestamp,
      orderId: request.orderId,
      lockerId: request.lockerId,
      boxId: request.effectivePortId,
      collectionToken: request.collectionToken,
      payload: PacketPayload.json({
        'reason': 'collection',
        'transactionId': request.transactionId,
        'port': request.port,
        if (request.advertisementId != null)
          'advertisementId': request.advertisementId,
        if (request.encryptionKeyId != null)
          'encryptionKeyId': request.encryptionKeyId,
        'encryption': null,
      }),
    );

    return _encodeLogged(packet, label: 'OPEN_BOX', request: request);
  }

  /// Build a PING packet (link check).
  Uint8List buildPing({
    String lockerId = '',
    int? frameCounter,
    int? timestamp,
  }) {
    final packet = Packet.build(
      type: BlePacketType.ping,
      sequenceNumber: frameCounter ?? nextFrameCounter(),
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      lockerId: lockerId,
    );
    return _encodeLogged(packet, label: 'PING');
  }

  /// Build a STATUS request.
  Uint8List buildStatus({
    required String lockerId,
    String boxId = '',
    int? frameCounter,
  }) {
    final packet = Packet.build(
      type: BlePacketType.status,
      sequenceNumber: frameCounter ?? nextFrameCounter(),
      lockerId: lockerId,
      boxId: boxId,
      payload: PacketPayload.statusRequest(),
    );
    return _encodeLogged(packet, label: 'STATUS');
  }

  /// Encode an arbitrary [Packet] (advanced / tests).
  Uint8List encode(Packet packet, {UnlockPacketRequest? request}) =>
      _encodeLogged(
        packet,
        label: packet.packetType.wireName,
        request: request,
      );

  Uint8List _encodeLogged(
    Packet packet, {
    required String label,
    UnlockPacketRequest? request,
  }) {
    final bytes = _codec.encode(packet);
    final port = request?.port ??
        packet.payload.asJsonMap()?['port'] as int?;

    BleLog.d('── PACKET TX ($label) ─────────────────────────');
    if (request != null) {
      BleLog.d('Transaction ID: ${request.transactionId}');
      BleLog.d('Locker ID: ${request.lockerId}');
      BleLog.d('Box Number: ${request.boxId}');
      BleLog.d('Port Number: ${request.port}');
    } else {
      BleLog.d('orderId: ${packet.header.orderId}');
      BleLog.d('Locker ID: ${packet.header.lockerId}');
      BleLog.d('Box Number: ${packet.header.boxId}');
      if (port != null) BleLog.d('Port Number: $port');
    }
    BleLog.d('Packet Length: ${bytes.length}');
    BleLog.d('Packet HEX: ${_hex(bytes)}');
    BleLog.d(
      'Header layout: Byte[0]=ver Byte[1]=type '
      'Byte[2..3]=seq(u16 BE) Byte[4..7]=timestamp — '
      'port is NOT in Byte[2]/3] (reserved for sequenceNumber)',
    );
    for (var i = 0; i < bytes.length && i < 32; i++) {
      final note = switch (i) {
        0 => ' protocolVersion',
        1 => ' packetType',
        2 => ' seq_hi (RESERVED — not port)',
        3 => ' seq_lo (RESERVED — not port)',
        4 => ' timestamp…',
        _ => '',
      };
      BleLog.d(
        'Byte[$i] = 0x${bytes[i].toRadixString(16).padLeft(2, '0')} '
        '(${bytes[i]})$note',
      );
    }
    if (port != null) {
      final portIdx = _findPortValueIndex(bytes, port);
      if (portIdx != null) {
        BleLog.d(
          'PORT=$port encoded in JSON payload at Byte[$portIdx] '
          '= 0x${bytes[portIdx].toRadixString(16).padLeft(2, '0')} '
          '(ASCII digit or multi-byte starts here)',
        );
      } else {
        BleLog.d('PORT=$port present in payload map (search index n/a)');
      }
      BleLog.d('PORT = $port');
      BleLog.d('BOX = ${request?.boxId ?? packet.header.boxId}');
      BleLog.d('TX HEX: ${_hex(bytes)}');
    }
    BleLog.d('──────────────────────────────────────────────');
    return bytes;
  }

  /// Locate the ASCII digits of `"port":N` inside the encoded frame.
  static int? _findPortValueIndex(Uint8List bytes, int port) {
    final needle = utf8.encode('"port":$port');
    final alt = utf8.encode('"port": $port');
    for (final pattern in [needle, alt]) {
      for (var i = 0; i <= bytes.length - pattern.length; i++) {
        var match = true;
        for (var j = 0; j < pattern.length; j++) {
          if (bytes[i + j] != pattern[j]) {
            match = false;
            break;
          }
        }
        if (match) {
          // Index of first digit of the port value.
          return i + pattern.length - '$port'.length;
        }
      }
    }
    return null;
  }

  static String _hex(Uint8List bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join(' ');
}
