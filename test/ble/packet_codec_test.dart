import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/ble.dart';

void main() {
  const codec = PacketCodec();

  test('encode/decode round-trip preserves AUTH fields', () {
    final packet = Packet.build(
      type: BlePacketType.auth,
      sequenceNumber: 7,
      timestamp: 1722691202,
      orderId: 'ORD-DEMO-1',
      lockerId: 'LCK-A1',
      boxId: 'BOX-03',
      collectionToken: 'CE1.ORD-DEMO-1.LCK-A1.BOX-03.1893456000.deadbeef',
      payload: PacketPayload.auth(
        tokenExpiresAt: 1893456000,
        phoneNonce: 'n1',
      ),
    );

    final frame = codec.encode(packet);
    final parsed = codec.decode(frame);

    expect(parsed.header.packetType, BlePacketType.auth);
    expect(parsed.header.sequenceNumber, 7);
    expect(parsed.header.orderId, 'ORD-DEMO-1');
    expect(parsed.header.lockerId, 'LCK-A1');
    expect(parsed.header.boxId, 'BOX-03');
    expect(parsed.header.collectionToken, contains('CE1.'));
    expect(parsed.payload.asJsonMap()?['phoneNonce'], 'n1');
    expect(parsed.checksum, packet.checksum);
  });

  test('checksum mismatch throws CRC_FAILED', () {
    final packet = Packet.build(
      type: BlePacketType.ping,
      sequenceNumber: 1,
      lockerId: 'LCK-A1',
    );
    final frame = codec.encode(packet);
    frame[8] = frame[8] ^ 0xff;
    expect(
      () => codec.decode(frame),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('CRC_FAILED'),
        ),
      ),
    );
  });

  test('validation rejects oversized orderId', () {
    final packet = Packet.build(
      type: BlePacketType.ping,
      sequenceNumber: 1,
      orderId: 'X' * 50,
    );
    expect(packet.isValid, isFalse);
  });
}
