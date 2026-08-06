import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/ble/ble.dart';

void main() {
  test('SequenceManager increments and skips 0 on wrap path', () {
    final seq = SequenceManager(initial: 1);
    expect(seq.next(), 1);
    expect(seq.next(), 2);
    final inbound = seq.acceptInbound(2);
    expect(inbound.accepted, isTrue);
    expect(seq.acceptInbound(2).duplicate, isTrue);
  });

  test('RetryManager backs off and respects maxAttempts', () {
    final retry = RetryManager(maxAttempts: 3, jitterRatio: 0);
    expect(
      retry.shouldRetry(attempt: 1, packetType: BlePacketType.openBox),
      isTrue,
    );
    expect(
      retry.shouldRetry(attempt: 3, packetType: BlePacketType.openBox),
      isFalse,
    );
    expect(
      retry.shouldRetry(
        attempt: 1,
        packetType: BlePacketType.openBox,
        errorCode: BleErrorCode.invalidToken,
      ),
      isFalse,
    );
    expect(retry.delayForAttempt(1).inMilliseconds, greaterThan(0));
  });

  test('TimeoutManager maps packet types', () {
    const timeouts = TimeoutManager();
    expect(timeouts.responseTimeout(BlePacketType.auth).inMilliseconds, 3000);
    expect(
      timeouts.responseTimeout(BlePacketType.openBox).inMilliseconds,
      5000,
    );
  });
}
