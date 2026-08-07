import '../../../core/ble/ble.dart';

/// Local packet fields for BLE Demo Mode (no backend / JWT).
///
/// Maps onto [UnlockPacketRequest] solely so [RealPacketBuilder] can fill the
/// fixed 32-byte firmware layout. Production Collect must not use this path.
class BleDemoPacketRequest {
  const BleDemoPacketRequest({
    required this.command,
    required this.port,
    required this.boxNumber,
    required this.terminalNumber,
    this.orderId = '',
    this.itemId = '',
    this.transactionId = '',
  });

  /// Firmware opcode (OPEN=0x01, AUTH=0x10, STATUS=0x30, or custom).
  final int command;

  final int port;
  final int boxNumber;
  final int terminalNumber;
  final String orderId;
  final String itemId;
  final String transactionId;

  UnlockPacketRequest toUnlockPacketRequest() {
    return UnlockPacketRequest(
      transactionId: transactionId,
      orderId: orderId,
      lockerId: 'DEMO',
      boxId: '$boxNumber',
      collectionToken: 'demo',
      port: port,
      boxNumber: boxNumber,
      terminalNumber: terminalNumber,
      itemId: itemId.isEmpty ? null : itemId,
    );
  }

  BleDemoPacketRequest copyWith({
    int? command,
    int? port,
    int? boxNumber,
    int? terminalNumber,
    String? orderId,
    String? itemId,
    String? transactionId,
  }) {
    return BleDemoPacketRequest(
      command: command ?? this.command,
      port: port ?? this.port,
      boxNumber: boxNumber ?? this.boxNumber,
      terminalNumber: terminalNumber ?? this.terminalNumber,
      orderId: orderId ?? this.orderId,
      itemId: itemId ?? this.itemId,
      transactionId: transactionId ?? this.transactionId,
    );
  }
}

/// Named command presets shown in the BLE Demo UI.
enum BleDemoCommandKind {
  open,
  auth,
  status,
  custom,
}

extension BleDemoCommandKindX on BleDemoCommandKind {
  String get label => switch (this) {
        BleDemoCommandKind.open => 'OPEN',
        BleDemoCommandKind.auth => 'AUTH',
        BleDemoCommandKind.status => 'STATUS',
        BleDemoCommandKind.custom => 'CUSTOM',
      };

  int get defaultOpcode => switch (this) {
        BleDemoCommandKind.open => FirmwareCommand.open,
        BleDemoCommandKind.auth => FirmwareCommand.auth,
        BleDemoCommandKind.status => FirmwareCommand.status,
        BleDemoCommandKind.custom => 0xFF,
      };
}
