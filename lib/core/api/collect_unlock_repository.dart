import '../ble/protocol/parsed_ble_response.dart';
import '../ble/transport/ble_log.dart';
import '../location/location_service.dart';
import 'api_client.dart';

/// Minimal BLE unlock fields from backend authorization (no Unlock JWT).
///
/// Phase 20 — Port, Terminal, and boxNumbers come from the order/locker DB.
/// Box selection uses the 4-byte firmware bitmap (never hardcoded).
class CollectUnlockInfo {
  const CollectUnlockInfo({
    required this.orderId,
    required this.lockerId,
    required this.terminalNumber,
    required this.port,
    required this.boxNumbers,
    this.itemId = '',
    this.transactionId = '',
    this.orderNumber = '',
  });

  final String orderId;
  final String lockerId;

  /// Firmware Byte[6] — locker.terminalNumber.
  final int terminalNumber;

  /// Firmware Byte[1] Port — from backend (may equal primary box).
  final int port;

  /// Physical boxes to unlock (1–32) → 4-byte bitmap.
  final List<int> boxNumbers;

  final String itemId;
  final String transactionId;
  final String orderNumber;

  /// Primary box for UI (first assigned).
  int get boxNumber => boxNumbers.isNotEmpty ? boxNumbers.first : 0;

  /// Build [UnlockPacketRequest] for Collect → [BleUnlockEngine] /
  /// [FinalUnlockPacketBuilder] (boxes → Port bitmap).
  UnlockPacketRequest toUnlockPacketRequest() {
    if (boxNumbers.isEmpty) {
      throw StateError('boxNumbers must not be empty');
    }
    for (final b in boxNumbers) {
      if (b < 1 || b > 32) {
        throw StateError('Invalid boxNumber from order: $b (must be 1–32)');
      }
    }
    if (port < 1 || port > 255) {
      throw StateError('Invalid port from order: $port');
    }
    if (terminalNumber < 1 || terminalNumber > 255) {
      throw StateError('Invalid terminalNumber from locker: $terminalNumber');
    }
    if (orderId.trim().isEmpty || lockerId.trim().isEmpty) {
      throw StateError('orderId / lockerId required from unlock-info');
    }

    final tx = transactionId.trim().isNotEmpty
        ? transactionId.trim()
        : (orderNumber.trim().isNotEmpty
            ? orderNumber.trim()
            : orderId.trim());

    final primary = boxNumbers.first;
    final request = UnlockPacketRequest(
      transactionId: tx,
      orderId: orderId.trim(),
      lockerId: lockerId.trim(),
      boxId: '$primary',
      collectionToken: 'collect', // unused by RealPacketBuilder
      port: port,
      boxNumber: primary,
      boxNumbers: List<int>.from(boxNumbers),
      terminalNumber: terminalNumber,
      itemId: itemId.trim().isEmpty ? null : itemId.trim(),
    );

    BleLog.d('── DYNAMIC COLLECT UNLOCK (Phase 20) ───────────');
    BleLog.d('Order ID: ${request.orderId}');
    BleLog.d('Locker ID: ${request.lockerId}');
    BleLog.d('Terminal: ${request.terminalNumber}');
    BleLog.d('Port: ${request.port}');
    BleLog.d('Boxes: ${request.effectiveBoxNumbers}');
    BleLog.d('Item ID: ${request.itemId ?? ''}');
    BleLog.d('Transaction ID: ${request.transactionId}');
    BleLog.d('──────────────────────────────────────────────');

    return request;
  }

  factory CollectUnlockInfo.fromJson(Map<String, dynamic> json) {
    final terminal = _positiveInt(json['terminalNumber'], max: 255);
    final port = _positiveInt(json['port'], max: 255) ??
        _positiveInt(json['boxNumber'], max: 32);
    final boxes = _parseBoxNumbers(json);
    if (terminal == null || port == null || boxes.isEmpty) {
      throw const FormatException(
        'unlock-info missing terminalNumber / port / boxNumbers',
      );
    }
    final orderId = asString(json['orderId'])?.trim() ?? '';
    final lockerId = asString(json['lockerId'])?.trim() ?? '';
    if (orderId.isEmpty || lockerId.isEmpty) {
      throw const FormatException('unlock-info missing orderId / lockerId');
    }
    return CollectUnlockInfo(
      orderId: orderId,
      lockerId: lockerId,
      terminalNumber: terminal,
      port: port,
      boxNumbers: boxes,
      itemId: asString(json['itemId'])?.trim() ?? '',
      transactionId: asString(json['transactionId'])?.trim() ?? '',
      orderNumber: asString(json['orderNumber'])?.trim() ?? '',
    );
  }

  static List<int> _parseBoxNumbers(Map<String, dynamic> json) {
    final raw = json['boxNumbers'];
    final out = <int>[];
    final seen = <int>{};
    if (raw is List) {
      for (final e in raw) {
        final n = _positiveInt(e, max: 32);
        if (n != null && seen.add(n)) out.add(n);
      }
    }
    if (out.isEmpty) {
      final single = _positiveInt(json['boxNumber'], max: 32);
      if (single != null) out.add(single);
    }
    return out;
  }

  static int? _positiveInt(dynamic value, {required int max}) {
    if (value is int) return value > 0 && value <= max ? value : null;
    if (value is num) {
      final n = value.toInt();
      return n > 0 && n <= max ? n : null;
    }
    final parsed = int.tryParse('$value');
    if (parsed == null || parsed <= 0 || parsed > max) return null;
    return parsed;
  }
}

/// Collect APIs — minimal unlock info + mark collected (no Unlock JWT).
class CollectUnlockRepository {
  CollectUnlockRepository(this._api);

  final ApiClient _api;

  /// `GET /orders/:id/unlock-info` — authorized minimal BLE fields from order DB.
  Future<CollectUnlockInfo> fetchUnlockInfo({required String orderId}) async {
    final id = orderId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(orderId, 'orderId', 'must not be empty');
    }
    final data = asMap(
      await _api.get('/orders/${Uri.encodeComponent(id)}/unlock-info'),
    );
    return CollectUnlockInfo.fromJson(data);
  }

  /// `POST /orders/:id/collect-complete` — mark order COLLECTED after BLE success.
  Future<void> markCollected({required String orderId}) async {
    final id = orderId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(orderId, 'orderId', 'must not be empty');
    }
    await _api.post('/orders/${Uri.encodeComponent(id)}/collect-complete');
  }
}
