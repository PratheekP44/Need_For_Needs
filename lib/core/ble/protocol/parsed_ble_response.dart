import 'dart:typed_data';

import '../models/packet.dart';
import '../protocol/packet_types.dart';

/// Classification of an inbound BLE notification / response.
enum BleResponseKind {
  ack,
  nack,
  unlockSuccess,
  unlockFailure,
  batteryStatus,
  doorStatus,
  authAccepted,
  authRejected,
  pingPong,
  error,
  unknown,
}

/// Strongly typed parse result for notify characteristic data.
class ParsedBleResponse {
  const ParsedBleResponse({
    required this.kind,
    required this.raw,
    required this.rawHex,
    this.packet,
    this.message,
    this.doorState,
    this.boxStatus,
    this.batteryMv,
    this.accepted,
    this.opened,
    this.errorCode,
    this.sequenceNumber,
  });

  final BleResponseKind kind;
  final Uint8List raw;
  final String rawHex;
  final Packet? packet;
  final String? message;
  final String? doorState;
  final String? boxStatus;
  final int? batteryMv;
  final bool? accepted;
  final bool? opened;
  final BleErrorCode? errorCode;
  final int? sequenceNumber;

  bool get isSuccess =>
      kind == BleResponseKind.unlockSuccess ||
      kind == BleResponseKind.authAccepted ||
      kind == BleResponseKind.ack ||
      kind == BleResponseKind.pingPong ||
      kind == BleResponseKind.doorStatus ||
      kind == BleResponseKind.batteryStatus;

  bool get isFailure =>
      kind == BleResponseKind.unlockFailure ||
      kind == BleResponseKind.authRejected ||
      kind == BleResponseKind.nack ||
      kind == BleResponseKind.error;

  @override
  String toString() =>
      'ParsedBleResponse(kind=$kind, seq=$sequenceNumber, '
      'opened=$opened, accepted=$accepted, door=$doorState, '
      'msg=$message, hex=$rawHex)';
}

/// Inputs required to build an unlock packet (Phase-10 or firmware 32-byte).
///
/// Production Collect builds this from backend unlock-info (no Unlock JWT).
/// Optional fields remain for tests / future encryption support.
class UnlockPacketRequest {
  const UnlockPacketRequest({
    required this.transactionId,
    required this.orderId,
    required this.lockerId,
    required this.boxId,
    required this.collectionToken,
    required this.port,
    this.boxNumber,
    this.boxNumbers,
    this.terminalNumber = 1,
    this.itemId,
    this.portId,
    this.bluetoothAddress,
    this.advertisementId,
    this.frameCounter,
    this.timestamp,
    this.tokenExpiresAt,
    this.phoneNonce,
    this.authPayload,
    this.encryptionKeyId,
  });

  /// Payment / order transaction id (logged; may also map to [orderId]).
  final String transactionId;

  final String orderId;

  /// Locker code / id used on the wire (`lockerId` header field).
  final String lockerId;

  /// Box label from payment/order (e.g. `BOX-03`, `3`, `Box 4`).
  final String boxId;

  /// Firmware Byte[1] Port — from backend/order (not the box bitmap).
  final int port;

  /// Single box number (legacy / single-line orders). Prefer [boxNumbers].
  final int? boxNumber;

  /// All boxes to unlock via the 4-byte firmware bitmap (Phase 20).
  final List<int>? boxNumbers;

  /// Firmware Byte[6] Terminal — from locker.terminalNumber.
  final int terminalNumber;

  /// Catalog / stock item id for firmware Item ID field.
  final String? itemId;

  /// Alias for [boxId] when firmware speaks in “port” terms.
  final String? portId;

  final String collectionToken;

  /// BLE MAC / remoteId when backend supplies it (scan fallback otherwise).
  final String? bluetoothAddress;

  /// Advertisement id / MSD correlation (future).
  final String? advertisementId;

  /// Explicit frame counter; when null the builder allocates via sequence.
  final int? frameCounter;

  /// Unix seconds; defaults to now.
  final int? timestamp;

  final int? tokenExpiresAt;
  final String? phoneNonce;

  /// Extra auth map merged into AUTH JSON payload (future encryption fields).
  final Map<String, Object?>? authPayload;

  /// Placeholder for future encryption key selection.
  final String? encryptionKeyId;

  /// Wire `boxId` header string (keeps token/box label; port is separate).
  String get effectivePortId =>
      (portId != null && portId!.isNotEmpty) ? portId! : boxId;

  /// Primary box number for logging / Phase-10 paths.
  int get effectiveBoxNumber => boxNumber ?? port;

  /// Boxes for the Phase 20 unlock bitmap (deduped later by mask builder).
  List<int> get effectiveBoxNumbers {
    if (boxNumbers != null && boxNumbers!.isNotEmpty) {
      return List<int>.from(boxNumbers!);
    }
    return [effectiveBoxNumber];
  }

  /// Parse box labels like `4`, `BOX-04`, `Box 3` → port number.
  static int portFromBoxId(String boxId) {
    final trimmed = boxId.trim();
    final asInt = int.tryParse(trimmed);
    if (asInt != null && asInt > 0) return asInt;
    final match = RegExp(r'(\d+)').firstMatch(trimmed);
    if (match != null) {
      final n = int.tryParse(match.group(1)!);
      if (n != null && n > 0) return n;
    }
    throw FormatException('Cannot derive port from boxId="$boxId"');
  }

  /// Parse terminal number from locker labels (`LCK-01`, `T3`, `2`).
  static int terminalFromLockerId(String lockerId) {
    final trimmed = lockerId.trim();
    final asInt = int.tryParse(trimmed);
    if (asInt != null && asInt > 0 && asInt <= 255) return asInt;
    final match = RegExp(r'(\d+)').firstMatch(trimmed);
    if (match != null) {
      final n = int.tryParse(match.group(1)!);
      if (n != null && n > 0 && n <= 255) return n;
    }
    return 1;
  }
}

/// Outcome of a full Collect → unlock session.
class UnlockResult {
  const UnlockResult({
    required this.success,
    required this.stage,
    this.message,
    this.deviceId,
    this.deviceName,
    this.mtu,
    this.authResponse,
    this.openResponse,
    this.backendConfirmed = false,
    this.error,
  });

  factory UnlockResult.ok({
    required String stage,
    String? message,
    String? deviceId,
    String? deviceName,
    int? mtu,
    ParsedBleResponse? authResponse,
    ParsedBleResponse? openResponse,
    bool backendConfirmed = false,
  }) =>
      UnlockResult(
        success: true,
        stage: stage,
        message: message ?? 'Locker Opened Successfully',
        deviceId: deviceId,
        deviceName: deviceName,
        mtu: mtu,
        authResponse: authResponse,
        openResponse: openResponse,
        backendConfirmed: backendConfirmed,
      );

  factory UnlockResult.fail({
    required String stage,
    required String message,
    Object? error,
    ParsedBleResponse? authResponse,
    ParsedBleResponse? openResponse,
  }) =>
      UnlockResult(
        success: false,
        stage: stage,
        message: message,
        error: error,
        authResponse: authResponse,
        openResponse: openResponse,
      );

  final bool success;
  final String stage;
  final String? message;
  final String? deviceId;
  final String? deviceName;
  final int? mtu;
  final ParsedBleResponse? authResponse;
  final ParsedBleResponse? openResponse;
  final bool backendConfirmed;
  final Object? error;
}
