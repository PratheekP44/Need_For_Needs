import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/models/unlock_payload.dart';
import 'package:need_for_needs/core/ble/unlock/unlock_jwt_decoder.dart';

const _secret = 'test_unlock_jwt_secret_min_32_chars!!';

void main() {
  final decoder = UnlockJwtDecoder(secret: _secret);
  final expiry = DateTime.now().toUtc().add(const Duration(minutes: 10));
  final issuedAt = DateTime.now().toUtc();

  Map<String, dynamic> sampleClaims({DateTime? expires}) {
    final exp = expires ?? expiry;
    return {
      'typ': 'unlock',
      'jti': 'jti-prod-001',
      'orderId': '507f1f77bcf86cd799439011',
      'transactionId': 'tx-100',
      'unlockToken': 'CE1.ORD-1.LCK-02.BOX-03.1893456000.deadbeef',
      'bluetoothAddress': 'AA:BB:CC:DD:EE:FF',
      'advertisementId': 'LKRM-V2-01',
      'terminalId': 2,
      'port': 3,
      'boxNumber': 3,
      'lockerId': 'LCK-02',
      'boxId': 'BOX-03',
      'itemId': 'ITEM-9',
      'issuedAt': issuedAt.toIso8601String(),
      'expiry': exp.toIso8601String(),
      'exp': exp.millisecondsSinceEpoch ~/ 1000,
    };
  }

  String signed([Map<String, dynamic>? claims]) =>
      UnlockJwtDecoder.signForTest(
        claims: claims ?? sampleClaims(),
        secret: _secret,
      );

  group('UnlockJwtDecoder', () {
    test('accepts valid HS256 signature', () {
      final claims = decoder.decodeAndVerify(signed());
      expect(claims['jti'], 'jti-prod-001');
      expect(claims['port'], 3);
    });

    test('rejects invalid signature', () {
      final bad = UnlockJwtDecoder.signForTest(
        claims: sampleClaims(),
        secret: 'wrong_secret_wrong_secret_wrong_!!',
      );
      expect(
        () => decoder.decodeAndVerify(bad),
        throwsA(
          isA<UnlockJwtException>().having(
            (e) => e.reason,
            'reason',
            'signature',
          ),
        ),
      );
    });

    test('rejects malformed token', () {
      expect(
        () => decoder.decodeAndVerify('not.a.jwt'),
        throwsA(isA<UnlockJwtException>()),
      );
    });
  });

  group('UnlockPayload.fromJwt', () {
    test('builds UnlockPayload only from verified JWT claims', () {
      final jwt = signed();
      final payload = UnlockPayload.fromJwt(jwt, decoder: decoder);

      expect(payload.jwt, jwt);
      expect(payload.jti, 'jti-prod-001');
      expect(payload.orderId, '507f1f77bcf86cd799439011');
      expect(payload.transactionId, 'tx-100');
      expect(payload.unlockToken, startsWith('CE1.'));
      expect(payload.bluetoothAddress, 'AA:BB:CC:DD:EE:FF');
      expect(payload.advertisementId, 'LKRM-V2-01');
      expect(payload.terminalId, 2);
      expect(payload.port, 3);
      expect(payload.boxNumber, 3);
      expect(payload.lockerId, 'LCK-02');
      expect(payload.boxId, 'BOX-03');
      expect(payload.itemId, 'ITEM-9');
      expect(payload.issuedAt.isUtc, isTrue);
    });

    test('toUnlockPacketRequest uses JWT fields only', () {
      final payload = UnlockPayload.fromJwt(signed(), decoder: decoder);
      final request = payload.toUnlockPacketRequest();
      expect(request.collectionToken, payload.unlockToken);
      expect(request.port, payload.port);
      expect(request.terminalNumber, payload.terminalId);
      expect(request.bluetoothAddress, payload.bluetoothAddress);
      expect(request.authPayload?['jti'], payload.jti);
      expect(request.authPayload?['jwt'], payload.jwt);
    });

    test('rejects expired JWT', () {
      final jwt = signed(
        sampleClaims(
          expires: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
        ),
      );
      expect(
        () => UnlockPayload.fromJwt(jwt, decoder: decoder),
        throwsA(
          isA<UnlockJwtException>().having((e) => e.reason, 'reason', 'expired'),
        ),
      );
    });

    test('rejects missing required claim', () {
      final claims = sampleClaims()..remove('unlockToken');
      expect(
        () => UnlockPayload.fromJwt(signed(claims), decoder: decoder),
        throwsA(
          isA<UnlockJwtException>()
              .having((e) => e.reason, 'reason', 'missing_field'),
        ),
      );
    });

    test('rejects empty bluetoothAddress (no fallback)', () {
      final claims = sampleClaims()..['bluetoothAddress'] = '';
      expect(
        () => UnlockPayload.fromJwt(signed(claims), decoder: decoder),
        throwsA(isA<UnlockJwtException>()),
      );
    });
  });
}
