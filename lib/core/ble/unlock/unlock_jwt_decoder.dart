import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../transport/ble_log.dart';

/// Errors while decoding / verifying an Unlock JWT.
class UnlockJwtException implements Exception {
  const UnlockJwtException(this.message, {this.reason = 'invalid'});

  final String message;
  final String reason;

  @override
  String toString() => message;
}

/// Decodes and HS256-verifies Unlock JWTs using [UNLOCK_JWT_SECRET].
///
/// Phone verifies integrity before building [UnlockPayload]. Replay consume
/// still happens on the backend via `jti` hooks.
class UnlockJwtDecoder {
  const UnlockJwtDecoder({required this.secret});

  /// Dedicated unlock signing secret (`UNLOCK_JWT_SECRET`). Never the auth secret.
  final String secret;

  /// Verifies signature, returns claims map.
  Map<String, dynamic> decodeAndVerify(String token) {
    final jwt = token.trim();
    if (jwt.isEmpty) {
      BleLog.e('Unlock JWT rejected: empty');
      throw const UnlockJwtException(
        'Unlock JWT is empty',
        reason: 'malformed',
      );
    }
    if (secret.isEmpty) {
      BleLog.e('Unlock JWT rejected: UNLOCK_JWT_SECRET not configured');
      throw const UnlockJwtException(
        'UNLOCK_JWT_SECRET is not configured on the client',
        reason: 'config',
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

    final signingInput = '${parts[0]}.${parts[1]}';
    final expected = _hs256Base64Url(signingInput, secret);
    if (!_constantTimeEquals(expected, parts[2])) {
      BleLog.e('Unlock JWT rejected: signature invalid');
      throw const UnlockJwtException(
        'Unlock JWT signature invalid',
        reason: 'signature',
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

  /// Alias kept for call sites that only need verified claims.
  Map<String, dynamic> decodeClaims(String token) => decodeAndVerify(token);

  static String _hs256Base64Url(String signingInput, String secret) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(signingInput));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static bool _constantTimeEquals(String a, String b) {
    final left = a.replaceAll('=', '');
    final right = b.replaceAll('=', '');
    if (left.length != right.length) return false;
    var diff = 0;
    for (var i = 0; i < left.length; i++) {
      diff |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return diff == 0;
  }

  static List<int> _base64UrlDecode(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    final mod = normalized.length % 4;
    if (mod > 0) {
      normalized = normalized.padRight(normalized.length + (4 - mod), '=');
    }
    return base64.decode(normalized);
  }

  /// Test helper: forge a compact HS256 Unlock JWT.
  static String signForTest({
    required Map<String, dynamic> claims,
    required String secret,
  }) {
    final header = base64Url
        .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
        .replaceAll('=', '');
    final payload =
        base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');
    final sig = _hs256Base64Url('$header.$payload', secret);
    return '$header.$payload.$sig';
  }
}
