import '../ble/models/unlock_payload.dart';
import '../ble/unlock/unlock_jwt_decoder.dart';
import '../location/location_service.dart';
import 'api_client.dart';

/// Fetches the production Unlock JWT (Phase 15B).
///
/// `POST /orders/:orderId/unlock-payload` → ApiClient unwraps `data` to `{ jwt }`.
/// Unlock fields are never read from the HTTP envelope.
/// Signature verification is backend-only — Flutter only decodes claims.
class UnlockPayloadRepository {
  UnlockPayloadRepository(
    this._api, {
    this.decoder = const UnlockJwtDecoder(),
  });

  final ApiClient _api;
  final UnlockJwtDecoder decoder;

  /// Requests JWT and builds [UnlockPayload] from decoded claims.
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

    final jwt = asString(data['jwt']);
    if (jwt == null || jwt.trim().isEmpty) {
      throw const UnlockJwtException(
        'Unlock API returned no jwt (expected data.jwt only)',
        reason: 'malformed',
      );
    }
    return jwt.trim();
  }
}
