import 'wire/packet_types.dart';

/// Collection-token format + expiry checks (crypto deferred to firmware phase).
class AuthenticationEngine {
  AuthenticationResult validate({
    required String token,
    required String expectedLockerId,
    String? expectedBoxId,
    bool forceInvalid = false,
    bool forceExpired = false,
    int clockSkewSeconds = 30,
  }) {
    if (forceInvalid) {
      return AuthenticationResult.fail(McuErrorCode.invalidToken, 'forced');
    }
    if (forceExpired) {
      return AuthenticationResult.fail(McuErrorCode.expiredToken, 'forced');
    }

    final parts = token.split('.');
    if (parts.length != 6 || parts.first != 'CE1') {
      return AuthenticationResult.fail(
        McuErrorCode.invalidToken,
        'malformed token',
      );
    }
    final orderId = parts[1];
    final lockerId = parts[2];
    final boxId = parts[3];
    final exp = int.tryParse(parts[4]);
    if (exp == null) {
      return AuthenticationResult.fail(McuErrorCode.invalidToken, 'bad expiry');
    }
    if (lockerId != expectedLockerId) {
      return AuthenticationResult.fail(
        McuErrorCode.invalidToken,
        'locker mismatch',
      );
    }
    if (expectedBoxId != null &&
        expectedBoxId.isNotEmpty &&
        boxId != expectedBoxId) {
      return AuthenticationResult.fail(
        McuErrorCode.invalidBox,
        'box mismatch',
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now > exp + clockSkewSeconds) {
      return AuthenticationResult.fail(
        McuErrorCode.expiredToken,
        'token expired',
      );
    }
    return AuthenticationResult.ok(
      orderId: orderId,
      lockerId: lockerId,
      boxId: boxId,
      expiresAt: exp,
    );
  }
}

class AuthenticationResult {
  AuthenticationResult._({
    required this.ok,
    this.orderId,
    this.lockerId,
    this.boxId,
    this.expiresAt,
    this.error,
    this.message,
  });

  factory AuthenticationResult.ok({
    required String orderId,
    required String lockerId,
    required String boxId,
    required int expiresAt,
  }) =>
      AuthenticationResult._(
        ok: true,
        orderId: orderId,
        lockerId: lockerId,
        boxId: boxId,
        expiresAt: expiresAt,
      );

  factory AuthenticationResult.fail(McuErrorCode error, String message) =>
      AuthenticationResult._(ok: false, error: error, message: message);

  final bool ok;
  final String? orderId;
  final String? lockerId;
  final String? boxId;
  final int? expiresAt;
  final McuErrorCode? error;
  final String? message;
}
