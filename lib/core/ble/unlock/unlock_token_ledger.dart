import '../transport/ble_log.dart';

/// Future replay-protection ledger for Unlock JWT `jti` values.
///
/// Persistence (Redis / DB) is intentionally not implemented yet — stubs only.
abstract class UnlockTokenLedger {
  /// Mark [jti] as consumed after a successful unlock.
  Future<void> markUnlockTokenUsed(String jti);

  /// Force-invalidate [jti] (cancel / security revoke).
  Future<void> invalidateUnlockToken(String jti);

  /// Whether [jti] was already used or invalidated.
  Future<bool> isUnlockTokenUsed(String jti);
}

/// In-memory stub ledger for local bring-up (not production-safe).
class InMemoryUnlockTokenLedger implements UnlockTokenLedger {
  final Set<String> _used = <String>{};
  final Set<String> _invalidated = <String>{};

  @override
  Future<void> markUnlockTokenUsed(String jti) async {
    final key = jti.trim();
    if (key.isEmpty) return;
    _used.add(key);
    BleLog.d('UnlockTokenLedger.markUnlockTokenUsed jti=$key');
  }

  @override
  Future<void> invalidateUnlockToken(String jti) async {
    final key = jti.trim();
    if (key.isEmpty) return;
    _invalidated.add(key);
    BleLog.d('UnlockTokenLedger.invalidateUnlockToken jti=$key');
  }

  @override
  Future<bool> isUnlockTokenUsed(String jti) async {
    final key = jti.trim();
    if (key.isEmpty) return false;
    return _used.contains(key) || _invalidated.contains(key);
  }
}
