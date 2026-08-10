import '../protocol/parsed_ble_response.dart';
import '../transport/ble_log.dart';
import '../unlock/unlock_jwt_decoder.dart';

/// Unlock session built **only** from a decoded Unlock JWT (Phase 15B).
///
/// Signature verification is server-side only. Flutter decodes claims over TLS,
/// validates `exp` / `iat` locally, then maps into this model.
class UnlockPayload {
  const UnlockPayload({
    required this.jwt,
    required this.jti,
    required this.orderId,
    required this.transactionId,
    required this.unlockToken,
    required this.bluetoothAddress,
    required this.advertisementId,
    required this.terminalId,
    required this.port,
    required this.boxNumber,
    required this.lockerId,
    required this.boxId,
    required this.issuedAt,
    required this.expiry,
    this.itemId,
  });

  final String jwt;
  final String jti;
  final String orderId;
  final String transactionId;
  final String unlockToken;
  final String bluetoothAddress;
  final String advertisementId;
  final int terminalId;
  final int port;
  final int boxNumber;
  final String lockerId;
  final String boxId;
  final DateTime issuedAt;
  final DateTime expiry;
  final String? itemId;

  bool get isExpired => !expiry.toUtc().isAfter(DateTime.now().toUtc());

  /// Decode payload (no signature check) + validate time claims → [UnlockPayload].
  factory UnlockPayload.fromJwt(
    String token, {
    UnlockJwtDecoder decoder = const UnlockJwtDecoder(),
    DateTime? now,
  }) {
    late final Map<String, dynamic> claims;
    try {
      claims = decoder.decodeClaims(token);
    } on UnlockJwtException {
      rethrow;
    } catch (e) {
      BleLog.e('Unlock JWT rejected: $e');
      throw UnlockJwtException(
        'Unlock JWT rejected: $e',
        reason: 'malformed',
      );
    }

    if (claims['typ'] != null && claims['typ'].toString() != 'unlock') {
      BleLog.e('Unlock JWT rejected: unexpected typ');
      throw UnlockJwtException(
        'Unexpected JWT typ=${claims['typ']} (expected unlock)',
        reason: 'malformed',
      );
    }

    final clock = (now ?? DateTime.now()).toUtc();
    _validateExpAndIat(claims, clock: clock);

    final jti = _requireString(claims, 'jti');
    final orderId = _requireString(claims, 'orderId');
    final transactionId = _requireString(claims, 'transactionId');
    final unlockToken = _requireString(claims, 'unlockToken');
    final bluetoothAddress = _requireString(claims, 'bluetoothAddress');
    final advertisementId = _requireString(claims, 'advertisementId');
    final terminalId = _requireInt(claims, 'terminalId');
    final port = _requireInt(claims, 'port');
    final boxNumber = _requireInt(claims, 'boxNumber');
    final lockerId = _requireString(claims, 'lockerId');
    final boxId = _requireString(claims, 'boxId');
    final issuedAt = _requireDateTime(claims, 'issuedAt');
    final expiry = _requireDateTime(claims, 'expiry');
    final itemId = _nullableString(claims, 'itemId');

    final payload = UnlockPayload(
      jwt: token.trim(),
      jti: jti,
      orderId: orderId,
      transactionId: transactionId,
      unlockToken: unlockToken,
      bluetoothAddress: bluetoothAddress,
      advertisementId: advertisementId,
      terminalId: terminalId,
      port: port,
      boxNumber: boxNumber,
      lockerId: lockerId,
      boxId: boxId,
      issuedAt: issuedAt,
      expiry: expiry,
      itemId: itemId,
    );

    payload.validateExpiration(now: clock);
    payload.validateForUnlock(checkExpiry: false);
    return payload;
  }

  /// Local time checks on standard JWT `exp` / `iat` (no signature verify).
  static void _validateExpAndIat(
    Map<String, dynamic> claims, {
    required DateTime clock,
  }) {
    final nowUnix = clock.millisecondsSinceEpoch ~/ 1000;

    final exp = _asUnixSeconds(claims['exp']);
    if (exp == null) {
      BleLog.e('Unlock JWT rejected: missing exp');
      throw const UnlockJwtException(
        'Unlock JWT missing required claim: exp',
        reason: 'missing_field',
      );
    }
    if (exp <= nowUnix) {
      BleLog.e('Unlock JWT rejected: exp in the past');
      throw UnlockJwtException(
        'Unlock JWT expired (exp=$exp)',
        reason: 'expired',
      );
    }

    final iat = _asUnixSeconds(claims['iat']);
    if (iat == null) {
      BleLog.e('Unlock JWT rejected: missing iat');
      throw const UnlockJwtException(
        'Unlock JWT missing required claim: iat',
        reason: 'missing_field',
      );
    }
    // Allow small clock skew (60s) for devices slightly ahead.
    if (iat > nowUnix + 60) {
      BleLog.e('Unlock JWT rejected: iat in the future');
      throw UnlockJwtException(
        'Unlock JWT issuedAt/iat is in the future (iat=$iat)',
        reason: 'malformed',
      );
    }
    if (iat > exp) {
      BleLog.e('Unlock JWT rejected: iat after exp');
      throw const UnlockJwtException(
        'Unlock JWT iat is after exp',
        reason: 'malformed',
      );
    }
  }

  static int? _asUnixSeconds(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw > 1000000000000 ? raw ~/ 1000 : raw;
    if (raw is num) {
      final n = raw.toInt();
      return n > 1000000000000 ? n ~/ 1000 : n;
    }
    return int.tryParse(raw.toString().trim());
  }

  void validateExpiration({DateTime? now}) {
    final clock = (now ?? DateTime.now()).toUtc();
    if (!expiry.toUtc().isAfter(clock)) {
      BleLog.e('Unlock JWT rejected: expired jti=$jti');
      throw UnlockJwtException(
        'Unlock JWT expired at ${expiry.toUtc().toIso8601String()}',
        reason: 'expired',
      );
    }
  }

  void validateForUnlock({bool checkExpiry = true}) {
    if (jti.isEmpty) {
      throw const UnlockJwtException(
        'UnlockPayload.jti is required',
        reason: 'missing_field',
      );
    }
    if (orderId.isEmpty ||
        transactionId.isEmpty ||
        unlockToken.isEmpty ||
        bluetoothAddress.isEmpty ||
        advertisementId.isEmpty ||
        lockerId.isEmpty ||
        boxId.isEmpty) {
      throw const UnlockJwtException(
        'UnlockPayload missing required string fields',
        reason: 'missing_field',
      );
    }
    if (port <= 0 || port > 255) {
      throw UnlockJwtException(
        'UnlockPayload.port out of range: $port',
        reason: 'missing_field',
      );
    }
    if (boxNumber <= 0 || boxNumber > 255) {
      throw UnlockJwtException(
        'UnlockPayload.boxNumber out of range: $boxNumber',
        reason: 'missing_field',
      );
    }
    if (terminalId <= 0 || terminalId > 255) {
      throw UnlockJwtException(
        'UnlockPayload.terminalId out of range: $terminalId',
        reason: 'missing_field',
      );
    }
    if (checkExpiry) validateExpiration();
  }

  /// Maps JWT-derived fields → BLE [UnlockPacketRequest] (no local invention).
  UnlockPacketRequest toUnlockPacketRequest() {
    validateForUnlock();
    final expiresAtUnix = expiry.toUtc().millisecondsSinceEpoch ~/ 1000;
    return UnlockPacketRequest(
      transactionId: transactionId,
      orderId: orderId,
      lockerId: lockerId,
      boxId: boxId,
      collectionToken: unlockToken,
      port: port,
      boxNumber: boxNumber,
      boxNumbers: [boxNumber],
      terminalNumber: terminalId,
      itemId: itemId,
      bluetoothAddress: bluetoothAddress,
      advertisementId: advertisementId,
      tokenExpiresAt: expiresAtUnix,
      authPayload: {
        'jwt': jwt,
        'jti': jti,
        'issuedAt': issuedAt.toUtc().toIso8601String(),
        'expiry': expiry.toUtc().toIso8601String(),
      },
    );
  }

  static String _requireString(Map<String, dynamic> json, String key) {
    final value = _nullableString(json, key);
    if (value == null || value.isEmpty) {
      BleLog.e('Unlock JWT rejected: missing claim $key');
      throw UnlockJwtException(
        'Unlock JWT missing required claim: $key',
        reason: 'missing_field',
      );
    }
    return value;
  }

  static String? _nullableString(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  static int _requireInt(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw != null) {
      final parsed = int.tryParse(raw.toString().trim());
      if (parsed != null) return parsed;
    }
    BleLog.e('Unlock JWT rejected: missing claim $key');
    throw UnlockJwtException(
      'Unlock JWT missing required claim: $key',
      reason: 'missing_field',
    );
  }

  static DateTime _requireDateTime(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw == null) {
      BleLog.e('Unlock JWT rejected: missing claim $key');
      throw UnlockJwtException(
        'Unlock JWT missing required claim: $key',
        reason: 'missing_field',
      );
    }
    if (raw is DateTime) return raw.toUtc();
    if (raw is int) {
      final ms = raw > 1000000000000 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
    if (raw is num) {
      final n = raw.toInt();
      final ms = n > 1000000000000 ? n : n * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
    final text = raw.toString().trim();
    final asInt = int.tryParse(text);
    if (asInt != null) {
      final ms = asInt > 1000000000000 ? asInt : asInt * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed.toUtc();
    BleLog.e('Unlock JWT rejected: malformed claim $key');
    throw UnlockJwtException(
      'Unlock JWT claim $key is malformed',
      reason: 'malformed',
    );
  }

  @override
  String toString() {
    final mac = bluetoothAddress.length >= 5
        ? '${bluetoothAddress.substring(0, 2)}:**:**:**:${bluetoothAddress.substring(bluetoothAddress.length - 5)}'
        : '***';
    return 'UnlockPayload(jti=$jti, order=$orderId, locker=$lockerId, '
        'box=$boxId, port=$port, terminal=$terminalId, ble=$mac, '
        'exp=${expiry.toUtc().toIso8601String()})';
  }
}
