import '../ble/models/unlock_payload.dart';
import '../ble/unlock/unlock_jwt_decoder.dart';
import '../config/env_config.dart';
import '../location/location_service.dart';
import 'api_client.dart';

/// Fetches the production Unlock JWT (Phase 15B).
///
/// `POST /orders/:orderId/unlock-payload` → ApiClient unwraps `data` to `{ jwt }`.
/// Unlock fields are never read from the HTTP envelope.
class UnlockPayloadRepository {
  UnlockPayloadRepository(
    this._api, {
    required EnvConfig config,
    UnlockJwtDecoder? decoder,
  }) : decoder = decoder ?? UnlockJwtDecoder(secret: config.unlockJwtSecret);

  final ApiClient _api;
  final UnlockJwtDecoder decoder;

  /// Requests JWT and builds [UnlockPayload] solely from verified claims.
  Future<UnlockPayload> fetch({required String orderId}) async {
    final jwt = await fetchJwt(orderId: orderId);
    return UnlockPayload.fromJwt(jwt, decoder: decoder);
  }

  /// Raw JWT string only.
  Future<String> fetchJwt({required String orderId}) async {
    final id = orderId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(orderId, 'orderId', 'must not be empty');
    }

    final data = asMap(
      await _api.post('/orders/${Uri.encodeComponent(id)}/unlock-payload'),
    );

    // Reject any attempt to use sibling unlock fields from the HTTP body.
    final jwt = asString(data['jwt']);
    if (jwt == null || jwt.trim().isEmpty) {
      throw const UnlockJwtException(
        'Unlock API returned no jwt (expected data.jwt only)',
        reason: 'malformed',
      );
    }
    if (data.keys.any((k) => k != 'jwt')) {
      // Tolerate envelope noise keys but never use them for UnlockPayload.
    }
    return jwt.trim();
  }
}
