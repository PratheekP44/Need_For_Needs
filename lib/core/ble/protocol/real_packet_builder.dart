import 'dart:convert';
import 'dart:typed_data';

import '../transport/ble_log.dart';
import 'box_unlock_mask.dart';
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
/// Professor-confirmed layout (Phase 20):
/// ```
/// Byte[0]       Command
/// Byte[1]       Port
/// Bytes[2..5]   Box unlock bitmap (4 bytes, see [BoxUnlockMask])
/// Byte[6]       Terminal
/// Bytes[7..14]  Order ID     (8 ASCII, 0x00-padded / truncated)
/// Bytes[15..22] Item ID      (8 ASCII, 0x00-padded / truncated)
/// Bytes[23..28] Transaction ID (6 ASCII, 0x00-padded / truncated)
/// Byte[29]      Reserved     (0x00)
/// Bytes[30..31] Checksum     (u16 BE over bytes 0..29)
/// ```
///
/// Does not use Phase-10 framing, JSON, or dynamic lengths.
class RealPacketBuilder {
  const RealPacketBuilder();

  static const int packetLength = 32;

  static const int _portOffset = 1;
  static const int _bitmapOffset = 2;
  static const int _bitmapLen = 4;
  static const int _terminalOffset = 6;
  static const int _orderIdOffset = 7;
  static const int _orderIdLen = 8;
  static const int _itemIdOffset = 15;
  static const int _itemIdLen = 8;
  static const int _txIdOffset = 23;
  static const int _txIdLen = 6;
  static const int _reservedOffset = 29;
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

  /// 32-bit unlock mask from box numbers — see [BoxUnlockMask.buildBoxUnlockMask].
  static int buildBoxUnlockMask(List<int> boxNumbers) =>
      BoxUnlockMask.buildBoxUnlockMask(boxNumbers);

  /// Four bitmap bytes — see [BoxUnlockMask.encodeBoxMask32].
  static Uint8List encodeBoxMask32(int mask) =>
      BoxUnlockMask.encodeBoxMask32(mask);

  /// Allocate exactly 32 bytes and fill every predefined field.
  Uint8List build({
    required int command,
    required UnlockPacketRequest request,
  }) {
    final packet = Uint8List(packetLength);

    final port = _u8(request.port);
    final terminal = _u8(request.terminalNumber);
    final boxes = request.effectiveBoxNumbers;
    final mask = BoxUnlockMask.buildBoxUnlockMask(boxes);
    final maskBytes = BoxUnlockMask.encodeBoxMask32(mask);

    packet[0] = command & 0xff;
    packet[_portOffset] = port;
    packet.setRange(
      _bitmapOffset,
      _bitmapOffset + _bitmapLen,
      maskBytes,
    );
    packet[_terminalOffset] = terminal;

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

    // Byte[29] reserved — already 0x00 from Uint8List allocation.
    assert(packet[_reservedOffset] == 0);

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
      terminal: terminal,
      boxes: boxes,
      mask: mask,
      maskBytes: maskBytes,
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
    required int terminal,
    required List<int> boxes,
    required int mask,
    required Uint8List maskBytes,
    required String orderId,
    required String itemId,
    required String transactionId,
  }) {
    BleLog.d('── REAL FIRMWARE PACKET (32 bytes) ─────────────');
    BleLog.d('ORDER: $orderId');
    BleLog.d('TERMINAL: $terminal');
    BleLog.d('PORT: $port');
    BleLog.d('BOXES: $boxes');
    BleLog.d('BOX MASK: ${BoxUnlockMask.maskHex(mask)}');
    BleLog.d('MASK BYTES: ${BoxUnlockMask.encodedHex(maskBytes)}');
    BleLog.d('PACKET LENGTH: ${packet.length}');
    for (var i = 0; i < packet.length; i++) {
      final label = switch (i) {
        0 => ' Command',
        1 => ' Port',
        >= 2 && <= 5 => ' BoxBitmap',
        6 => ' Terminal',
        >= 7 && <= 14 => ' OrderID',
        >= 15 && <= 22 => ' ItemID',
        >= 23 && <= 28 => ' TxID',
        29 => ' Reserved',
        30 || 31 => ' Checksum',
        _ => '',
      };
      BleLog.d(
        'Byte[$i] = 0x${packet[i].toRadixString(16).padLeft(2, '0')} '
        '(${packet[i]})$label',
      );
    }
    BleLog.d(
      'PACKET HEX: ${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
    BleLog.d('Command: 0x${command.toRadixString(16).padLeft(2, '0')}');
    BleLog.d('Item ID: $itemId');
    BleLog.d('Transaction ID: $transactionId');
    BleLog.d('──────────────────────────────────────────────');
  }
}
