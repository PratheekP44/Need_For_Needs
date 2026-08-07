import '../../api/unlock_payload_repository.dart';
import '../../services/base_service.dart';
import '../models/unlock_payload.dart';
import '../protocol/parsed_ble_response.dart';
import '../transport/ble_log.dart';
import 'unlock_token_ledger.dart';

/// Stores the JWT-derived [UnlockPayload] for Collect (Phase 15B production).
class UnlockPayloadService extends BaseService {
  UnlockPayloadService(
    this._repository, {
    UnlockTokenLedger? ledger,
  }) : _ledger = ledger ?? InMemoryUnlockTokenLedger();

  final UnlockPayloadRepository _repository;
  final UnlockTokenLedger _ledger;

  UnlockPayload? _current;

  UnlockPayload? get current => _current;
  bool get hasPayload => _current != null;
  String? get currentJti => _current?.jti;
  UnlockTokenLedger get ledger => _ledger;

  /// Fetch JWT → verify → validate expiry → store.
  Future<UnlockPayload> requestPayload({required String orderId}) async {
    BleLog.d('UnlockPayloadService.request orderId=$orderId');
    final payload = await _repository.fetch(orderId: orderId);
    payload.validateForUnlock();
    _current = payload;
    BleLog.d(
      'UnlockPayloadService.stored jti=${payload.jti} '
      'expires=${payload.expiry.toUtc().toIso8601String()}',
    );
    return payload;
  }

  UnlockPacketRequest toPacketRequest([UnlockPayload? payload]) {
    final source = payload ?? _current;
    if (source == null) {
      throw StateError(
        'No UnlockPayload stored — call requestPayload() after payment success',
      );
    }
    BleLog.d('Unlock request jti=${source.jti}');
    return source.toUnlockPacketRequest();
  }

  // ── Future replay-protection hooks (stubs via ledger) ──────────────

  Future<void> markUnlockTokenUsed([String? jti]) =>
      _ledger.markUnlockTokenUsed(jti ?? currentJti ?? '');

  Future<void> invalidateUnlockToken([String? jti]) =>
      _ledger.invalidateUnlockToken(jti ?? currentJti ?? '');

  Future<bool> isUnlockTokenUsed([String? jti]) =>
      _ledger.isUnlockTokenUsed(jti ?? currentJti ?? '');

  /// Future: confirm unlock with backend using jti (one-time consume).
  Future<bool> confirmOneTimeUnlock({
    UnlockPayload? payload,
    Future<bool> Function(String jti, String jwt)? confirmWithBackend,
  }) async {
    final source = payload ?? _current;
    if (source == null) {
      BleLog.e('confirmOneTimeUnlock: no payload');
      return false;
    }
    final confirm = confirmWithBackend;
    if (confirm == null) {
      BleLog.d('confirmOneTimeUnlock: hook not wired (jti=${source.jti})');
      return false;
    }
    final ok = await confirm(source.jti, source.jwt);
    if (ok) await markUnlockTokenUsed(source.jti);
    return ok;
  }

  void clear() {
    _current = null;
    BleLog.d('UnlockPayloadService.cleared');
  }
}
