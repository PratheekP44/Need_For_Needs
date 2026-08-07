import 'dart:convert';

import '../transport/ble_log.dart';

/// Errors while decoding an Unlock JWT payload.
class UnlockJwtException implements Exception {
  const UnlockJwtException(this.message, {this.reason = 'invalid'});

  final String message;
  final String reason;

  @override
  String toString() => message;
}

/// Decodes Unlock JWT payloads without verifying the signature.
///
/// The signing secret (`UNLOCK_JWT_SECRET`) lives only on the backend.
/// Flutter trusts the TLS-authenticated API response and validates `exp`/`iat`
/// locally before building [UnlockPayload].
class UnlockJwtDecoder {
  const UnlockJwtDecoder();

  /// Base64url-decodes the JWT payload segment → claims map.
  Map<String, dynamic> decodeClaims(String token) {
    final jwt = token.trim();
    if (jwt.isEmpty) {
      BleLog.e('Unlock JWT rejected: empty');
      throw const UnlockJwtException(
        'Unlock JWT is empty',
        reason: 'malformed',
      );
    }

    final parts = jwt.split('.');
    if (parts.length != 3) {
      BleLog.e('Unlock JWT rejected: malformed segments');
      throw const UnlockJwtException(
        'Unlock JWT must have three base64url segments',
        reason: 'malformed',
      );
    }

    Map<String, dynamic> claims;
    try {
      final payloadJson = utf8.decode(_base64UrlDecode(parts[1]));
      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map) {
        throw const FormatException('payload not object');
      }
      claims = Map<String, dynamic>.from(decoded);
    } catch (_) {
      BleLog.e('Unlock JWT rejected: malformed payload');
      throw const UnlockJwtException(
        'Unlock JWT payload is malformed',
        reason: 'malformed',
      );
    }

    final jti = claims['jti']?.toString() ?? '';
    BleLog.d(
      'Unlock JWT decoded jti=${jti.isEmpty ? '(missing)' : jti} '
      'orderId=${claims['orderId'] ?? ''} '
      'expiry=${claims['expiry'] ?? claims['exp'] ?? ''}',
    );
    return claims;
  }

  static List<int> _base64UrlDecode(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    final mod = normalized.length % 4;
    if (mod > 0) {
      normalized = normalized.padRight(normalized.length + (4 - mod), '=');
    }
    return base64.decode(normalized);
  }

  /// Test helper: compact JWT with unsigned signature segment.
  static String forgeForTest(Map<String, dynamic> claims) {
    final header = base64Url
        .encode(utf8.encode(jsonEncode({'alg': 'none', 'typ': 'JWT'})))
        .replaceAll('=', '');
    final payload =
        base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');
    return '$header.$payload.fakesig';
  }
}
