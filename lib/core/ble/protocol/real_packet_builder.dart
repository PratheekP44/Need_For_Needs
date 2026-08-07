import 'dart:convert';
import 'dart:typed_data';

import '../transport/ble_log.dart';
import 'checksum.dart';
import 'parsed_ble_response.dart';

/// Firmware command opcodes for the fixed 32-byte packet.
abstract final class FirmwareCommand {
  static const int open = 0x01;
  static const int auth = 0x10;
  static const int status = 0x30;
}

/// Fixed 32-byte firmware packet builder (real hardware only).
///
/// Layout (Dart indexes 0–31):
/// ```
/// Byte[0]       Command
/// Byte[1]       Port Number (= box number)
/// Byte[2]       Box Number
/// Byte[3]       Terminal Number
/// Bytes[4..11]  Order ID     (8 ASCII, 0x00-padded / truncated)
/// Bytes[12..19] Item ID      (8 ASCII, 0x00-padded / truncated)
/// Bytes[20..27] Transaction ID (8 ASCII, 0x00-padded / truncated)
/// Bytes[28..29] Reserved     (0x00)
/// Bytes[30..31] Checksum     (u16 BE, existing placeholder over bytes 0..29)
/// ```
///
/// Does not use Phase-10 framing, JSON, or dynamic lengths.
class RealPacketBuilder {
  const RealPacketBuilder();

  static const int packetLength = 32;
  static const int _orderIdOffset = 4;
  static const int _orderIdLen = 8;
  static const int _itemIdOffset = 12;
  static const int _itemIdLen = 8;
  static const int _txIdOffset = 20;
  static const int _txIdLen = 8;
  static const int _reservedOffset = 28;
  static const int _checksumOffset = 30;

  /// Build an OPEN (unlock) packet — primary Collect write.
  Uint8List buildOpen(UnlockPacketRequest request) =>
      build(command: FirmwareCommand.open, request: request);

  /// Build an AUTH packet with the same fixed layout (optional).
  Uint8List buildAuth(UnlockPacketRequest request) =>
      build(command: FirmwareCommand.auth, request: request);

  /// Build a STATUS request packet.
  Uint8List buildStatus(UnlockPacketRequest request) =>
      build(command: FirmwareCommand.status, request: request);

  /// Allocate exactly 32 bytes and fill every predefined field.
  Uint8List build({
    required int command,
    required UnlockPacketRequest request,
  }) {
    final packet = Uint8List(packetLength);

    final port = _u8(request.port);
    final box = _u8(request.effectiveBoxNumber);
    final terminal = _u8(request.terminalNumber);

    packet[0] = command & 0xff;
    packet[1] = port;
    packet[2] = box;
    packet[3] = terminal;

    _writeAsciiField(
      packet,
      offset: _orderIdOffset,
      length: _orderIdLen,
      value: request.orderId,
    );
    _writeAsciiField(
      packet,
      offset: _itemIdOffset,
      length: _itemIdLen,
      value: request.itemId ?? '',
    );
    _writeAsciiField(
      packet,
      offset: _txIdOffset,
      length: _txIdLen,
      value: request.transactionId,
    );

    // Bytes[28..29] reserved — already 0x00 from Uint8List allocation.
    assert(packet[_reservedOffset] == 0 && packet[_reservedOffset + 1] == 0);

    final body = Uint8List.sublistView(packet, 0, _checksumOffset);
    final checksum = computeChecksumPlaceholder(body);
    ByteData.sublistView(packet).setUint16(
      _checksumOffset,
      checksum & 0xffff,
      Endian.big,
    );

    assert(packet.length == packetLength);
    _logPacket(
      packet,
      command: command,
      port: port,
      box: box,
      terminal: terminal,
      orderId: request.orderId,
      itemId: request.itemId ?? '',
      transactionId: request.transactionId,
    );
    return packet;
  }

  static void _writeAsciiField(
    Uint8List packet, {
    required int offset,
    required int length,
    required String value,
  }) {
    final encoded = utf8.encode(value);
    final n = encoded.length < length ? encoded.length : length;
    for (var i = 0; i < n; i++) {
      packet[offset + i] = encoded[i];
    }
    // Remaining bytes stay 0x00 (unused / reserved padding).
  }

  static int _u8(int value) {
    if (value < 0 || value > 255) {
      throw ArgumentError('Value $value out of u8 range for firmware packet');
    }
    return value;
  }

  static void _logPacket(
    Uint8List packet, {
    required int command,
    required int port,
    required int box,
    required int terminal,
    required String orderId,
    required String itemId,
    required String transactionId,
  }) {
    BleLog.d('── REAL FIRMWARE PACKET (32 bytes) ─────────────');
    BleLog.d('Packet length: ${packet.length}');
    for (var i = 0; i < packet.length; i++) {
      final label = switch (i) {
        0 => ' Command',
        1 => ' Port',
        2 => ' Box',
        3 => ' Terminal',
        >= 4 && <= 11 => ' OrderID',
        >= 12 && <= 19 => ' ItemID',
        >= 20 && <= 27 => ' TxID',
        28 || 29 => ' Reserved',
        30 || 31 => ' Checksum',
        _ => '',
      };
      BleLog.d(
        'Byte[$i] = 0x${packet[i].toRadixString(16).padLeft(2, '0')} '
        '(${packet[i]})$label',
      );
    }
    BleLog.d(
      'Packet HEX: ${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
    BleLog.d('Command: 0x${command.toRadixString(16).padLeft(2, '0')}');
    BleLog.d('Port: $port');
    BleLog.d('Box: $box');
    BleLog.d('Terminal: $terminal');
    BleLog.d('Order ID: $orderId');
    BleLog.d('Item ID: $itemId');
    BleLog.d('Transaction ID: $transactionId');
    BleLog.d('──────────────────────────────────────────────');
  }
}
