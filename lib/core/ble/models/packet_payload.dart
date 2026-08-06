import 'dart:convert';
import 'dart:typed_data';

import '../protocol/packet_types.dart';

/// Variable payload of a BLE packet (JSON UTF-8 or raw bytes).
class PacketPayload {
  const PacketPayload._(this.bytes);

  factory PacketPayload.empty() => PacketPayload._(Uint8List(0));

  factory PacketPayload.raw(Uint8List bytes) => PacketPayload._(bytes);

  factory PacketPayload.json(Map<String, Object?> map) =>
      PacketPayload._(Uint8List.fromList(utf8.encode(jsonEncode(map))));

  factory PacketPayload.auth({
    int? tokenIssuedAt,
    int? tokenExpiresAt,
    String? phoneNonce,
  }) =>
      PacketPayload.json({
        'tokenIssuedAt': tokenIssuedAt,
        'tokenExpiresAt': tokenExpiresAt,
        'phoneNonce': phoneNonce,
      });

  factory PacketPayload.authAck({
    required bool accepted,
    int sessionTtlSeconds = 120,
    String firmwareVersion = 'unknown',
  }) =>
      PacketPayload.json({
        'accepted': accepted,
        'sessionTtlSeconds': sessionTtlSeconds,
        'firmwareVersion': firmwareVersion,
      });

  factory PacketPayload.openBox({String reason = 'collection'}) =>
      PacketPayload.json({'reason': reason});

  factory PacketPayload.openAck({
    required bool opened,
    String doorState = 'UNKNOWN',
    String boxStatus = 'UNKNOWN',
  }) =>
      PacketPayload.json({
        'opened': opened,
        'doorState': doorState,
        'boxStatus': boxStatus,
      });

  factory PacketPayload.statusRequest({bool includeDoor = true}) =>
      PacketPayload.json({'includeDoor': includeDoor});

  factory PacketPayload.statusResponse({
    String doorState = 'UNKNOWN',
    String boxStatus = 'UNKNOWN',
    int? batteryMv,
    int? uptimeSeconds,
  }) =>
      PacketPayload.json({
        'doorState': doorState,
        'boxStatus': boxStatus,
        'batteryMv': batteryMv,
        'uptimeSeconds': uptimeSeconds,
      });

  factory PacketPayload.error({
    required BleErrorCode code,
    String message = '',
    bool? retryable,
  }) =>
      PacketPayload.json({
        'code': code.code,
        'name': code.wireName,
        'message': message,
        'retryable': retryable ?? code.retryable,
      });

  factory PacketPayload.heartbeat({int? rssi}) =>
      PacketPayload.json({'rssi': rssi});

  final Uint8List bytes;

  int get length => bytes.length;

  Map<String, Object?>? asJsonMap() {
    if (bytes.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
