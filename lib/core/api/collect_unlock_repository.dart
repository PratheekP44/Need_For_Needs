import '../ble/protocol/parsed_ble_response.dart';
import '../ble/transport/ble_log.dart';
import '../location/location_service.dart';
import 'api_client.dart';

/// Minimal BLE unlock fields from backend authorization (no Unlock JWT).
///
/// Phase 18 — all Port / Box / Terminal values come from the order/locker DB.
/// Nothing is hardcoded to 1.
class CollectUnlockInfo {
  const CollectUnlockInfo({
    required this.orderId,
    required this.lockerId,
    required this.terminalNumber,
    required this.boxNumber,
    this.itemId = '',
    this.transactionId = '',
    this.orderNumber = '',
  });

  final String orderId;
  final String lockerId;

  /// Firmware Byte[3] — from locker.terminalNumber.
  final int terminalNumber;

  /// Firmware Byte[1] and Byte[2] — from order box.boxNumber (Port = Box).
  final int boxNumber;

  final String itemId;
  final String transactionId;
  final String orderNumber;

  /// Firmware Port equals Box for current controller firmware.
  int get port => boxNumber;

  /// Build [UnlockPacketRequest] for [BleUnlockEngine] / [RealPacketBuilder].
  ///
  /// Mapping (dynamic from order — never hardcoded):
  /// - port = boxNumber
  /// - box = boxNumber
  /// - terminal = terminalNumber
  /// - orderId / itemId / transactionId from order
  UnlockPacketRequest toUnlockPacketRequest() {
    if (boxNumber < 1 || boxNumber > 255) {
      throw StateError('Invalid boxNumber from order: $boxNumber');
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

    final request = UnlockPacketRequest(
      transactionId: tx,
      orderId: orderId.trim(),
      lockerId: lockerId.trim(),
      boxId: '$boxNumber',
      collectionToken: 'collect', // unused by RealPacketBuilder
      port: boxNumber,
      boxNumber: boxNumber,
      terminalNumber: terminalNumber,
      itemId: itemId.trim().isEmpty ? null : itemId.trim(),
    );

    BleLog.d('── DYNAMIC COLLECT UNLOCK (Phase 18) ───────────');
    BleLog.d('Order ID: ${request.orderId}');
    BleLog.d('Locker ID: ${request.lockerId}');
    BleLog.d('Terminal: ${request.terminalNumber}');
    BleLog.d('Port: ${request.port}');
    BleLog.d('Box: ${request.effectiveBoxNumber}');
    BleLog.d('Item ID: ${request.itemId ?? ''}');
    BleLog.d('Transaction ID: ${request.transactionId}');
    BleLog.d('──────────────────────────────────────────────');

    return request;
  }

  factory CollectUnlockInfo.fromJson(Map<String, dynamic> json) {
    final terminal = _positiveInt(json['terminalNumber']);
    // Prefer boxNumber; accept port only if box missing (still DB-sourced).
    final box = _positiveInt(json['boxNumber']) ?? _positiveInt(json['port']);
    if (terminal == null || box == null) {
      throw const FormatException(
        'unlock-info missing terminalNumber / boxNumber',
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
      boxNumber: box,
      itemId: asString(json['itemId'])?.trim() ?? '',
      transactionId: asString(json['transactionId'])?.trim() ?? '',
      orderNumber: asString(json['orderNumber'])?.trim() ?? '',
    );
  }

  static int? _positiveInt(dynamic value) {
    if (value is int) return value > 0 && value <= 255 ? value : null;
    if (value is num) {
      final n = value.toInt();
      return n > 0 && n <= 255 ? n : null;
    }
    final parsed = int.tryParse('$value');
    if (parsed == null || parsed <= 0 || parsed > 255) return null;
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
