import 'dart:math';

import '../protocol/packet_types.dart';

/// Retry policy for request/response pairs (Phase 10 defaults).
class RetryManager {
  RetryManager({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 400),
    this.maxDelay = const Duration(milliseconds: 3000),
    this.jitterRatio = 0.2,
    Set<BlePacketType>? retryableTypes,
    Set<BleErrorCode>? retryableErrors,
  })  : retryableTypes = retryableTypes ??
            {
              BlePacketType.ping,
              BlePacketType.auth,
              BlePacketType.openBox,
              BlePacketType.status,
              BlePacketType.heartbeat,
            },
        retryableErrors = retryableErrors ??
            {
              BleErrorCode.lockerBusy,
              BleErrorCode.bleTimeout,
              BleErrorCode.crcFailed,
            };

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final double jitterRatio;
  final Set<BlePacketType> retryableTypes;
  final Set<BleErrorCode> retryableErrors;
  final Random _random = Random();

  bool shouldRetry({
    required int attempt,
    required BlePacketType packetType,
    BleErrorCode? errorCode,
    bool fatal = false,
  }) {
    if (fatal) return false;
    if (attempt >= maxAttempts) return false;
    if (!retryableTypes.contains(packetType)) return false;
    if (errorCode != null && !retryableErrors.contains(errorCode)) {
      return false;
    }
    return true;
  }

  /// [attempt] is 1-based for the next try after a failure.
  Duration delayForAttempt(int attempt) {
    final expMs = min(
      maxDelay.inMilliseconds,
      baseDelay.inMilliseconds * (1 << max(0, attempt - 1)),
    );
    final jitter = expMs * jitterRatio * _random.nextDouble();
    return Duration(
      milliseconds: min(maxDelay.inMilliseconds, (expMs + jitter).round()),
    );
  }
}
