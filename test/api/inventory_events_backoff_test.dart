import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/api/api_client.dart';
import 'package:need_for_needs/core/api/inventory_events_client.dart';
import 'package:need_for_needs/core/config/env_config.dart';

void main() {
  group('InventoryEventsClient.computeBackoff', () {
    test('increases with failure count and caps at 60s', () {
      final fixed = Random(1);
      final d0 = InventoryEventsClient.computeBackoff(
        failureCount: 0,
        random: fixed,
      );
      final d1 = InventoryEventsClient.computeBackoff(
        failureCount: 1,
        random: fixed,
      );
      final d2 = InventoryEventsClient.computeBackoff(
        failureCount: 2,
        random: fixed,
      );
      final dHigh = InventoryEventsClient.computeBackoff(
        failureCount: 20,
        random: fixed,
      );

      // Base without jitter: 2s, 4s, 8s — allow jitter up to +25%.
      expect(d0.inMilliseconds, greaterThanOrEqualTo(2000));
      expect(d0.inMilliseconds, lessThanOrEqualTo(2500));
      expect(d1.inMilliseconds, greaterThanOrEqualTo(4000));
      expect(d1.inMilliseconds, lessThanOrEqualTo(5000));
      expect(d2.inMilliseconds, greaterThanOrEqualTo(8000));
      expect(d2.inMilliseconds, lessThanOrEqualTo(10000));
      expect(dHigh.inMilliseconds, lessThanOrEqualTo(60000));
      expect(d1.inMilliseconds, greaterThan(d0.inMilliseconds));
      expect(d2.inMilliseconds, greaterThan(d1.inMilliseconds));
    });

    test('never reconnects on a fixed 3s cadence', () {
      final delays = <int>[];
      for (var i = 0; i < 6; i++) {
        delays.add(
          InventoryEventsClient.computeBackoff(
            failureCount: i,
            random: Random(42),
          ).inMilliseconds,
        );
      }
      expect(delays.toSet().length, greaterThan(1));
      expect(delays.every((ms) => ms == 3000), isFalse);
      expect(delays.last, greaterThan(delays.first));
    });
  });

  group('InventoryEventsClient reconnect loop', () {
    InventoryEventsClient makeClient({
      required Future<String?> Function() tokenReader,
      required Duration Function(int failureCount) backoff,
    }) {
      return InventoryEventsClient(
        session: SessionStore(),
        config: const EnvConfig(
          environment: AppEnvironment.development,
          apiBaseUrl: 'https://example.invalid',
        ),
        accessTokenReader: tokenReader,
        backoffForAttempt: backoff,
      );
    }

    test('stop cancels pending backoff and prevents further reconnects',
        () async {
      final delays = <Duration>[];
      final client = makeClient(
        tokenReader: () async => null,
        backoff: (n) {
          final d = Duration(milliseconds: 50 * (n + 1));
          delays.add(d);
          return d;
        },
      );

      // ignore: unawaited_futures
      final started = client.start();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(client.isLoopRunning, isTrue);

      await client.stop();
      expect(client.isLoopRunning, isFalse);
      expect(client.failureCount, 0);

      final failuresAfterStop = delays.length;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(delays.length, failuresAfterStop);
      await started;
    });

    test('manual start resets backoff after failures', () async {
      final seen = <int>[];
      final client = makeClient(
        tokenReader: () async => null,
        backoff: (n) {
          seen.add(n);
          return const Duration(milliseconds: 25);
        },
      );

      // ignore: unawaited_futures
      final first = client.start();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(seen, isNotEmpty);
      expect(seen.first, 0);
      expect(seen.last, greaterThanOrEqualTo(1));
      await client.stop();
      await first;

      seen.clear();
      // ignore: unawaited_futures
      final second = client.start();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(seen, isNotEmpty);
      expect(seen.first, 0);
      await client.stop();
      await second;
    });

    test('start while already running replaces with a single loop', () async {
      var starts = 0;
      final client = makeClient(
        tokenReader: () async {
          starts += 1;
          return null;
        },
        backoff: (_) => const Duration(milliseconds: 30),
      );

      // ignore: unawaited_futures
      final a = client.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // ignore: unawaited_futures
      final b = client.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await client.stop();
      await a;
      await b;
      // Second start() stops the first; only one loop remains active.
      expect(client.isLoopRunning, isFalse);
      expect(starts, greaterThan(0));
    });
  });
}
