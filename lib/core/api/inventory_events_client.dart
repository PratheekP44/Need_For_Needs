import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env_config.dart';
import 'api_client.dart';

/// Listens to `GET /events/inventory` (SSE) and notifies [onEvent].
///
/// Reconnects with bounded exponential backoff + jitter so a failing SSE
/// path cannot hammer the global API rate limit.
class InventoryEventsClient {
  InventoryEventsClient({
    required this.session,
    required this.config,
    this.onEvent,
    Random? random,
    @visibleForTesting this._backoffForAttempt,
    @visibleForTesting this._accessTokenReader,
  }) : _random = random ?? Random();

  final SessionStore session;
  final EnvConfig config;
  final void Function(Map<String, dynamic> event)? onEvent;

  final Random _random;
  final Duration Function(int failureCount)? _backoffForAttempt;
  final Future<String?> Function()? _accessTokenReader;

  http.Client? _client;
  StreamSubscription<String>? _sub;
  bool _stopped = true;
  bool _loopRunning = false;
  int _failureCount = 0;
  Completer<void>? _delayCompleter;
  Future<void>? _loopFuture;

  /// Consecutive reconnect failures (resets after a successful SSE open).
  @visibleForTesting
  int get failureCount => _failureCount;

  @visibleForTesting
  bool get isLoopRunning => _loopRunning;

  /// Bounded exponential backoff: 2s → 4s → 8s … capped at 60s, plus jitter.
  @visibleForTesting
  static Duration computeBackoff({
    required int failureCount,
    required Random random,
    int initialMs = 2000,
    int maxMs = 60000,
  }) {
    final attempt = failureCount < 0 ? 0 : failureCount;
    // Cap shift to avoid int overflow (2^15 * 2000 still fine).
    final shift = attempt > 15 ? 15 : attempt;
    var ms = initialMs * (1 << shift);
    if (ms > maxMs || ms <= 0) ms = maxMs;
    final jitterSpan = (ms ~/ 4).clamp(0, maxMs);
    final jitter = jitterSpan <= 0 ? 0 : random.nextInt(jitterSpan + 1);
    final total = ms + jitter;
    return Duration(milliseconds: total > maxMs ? maxMs : total);
  }

  Duration _delayForFailure(int failureCount) {
    final custom = _backoffForAttempt;
    if (custom != null) return custom(failureCount);
    return computeBackoff(failureCount: failureCount, random: _random);
  }

  /// Start (or restart) the single reconnect loop. Resets backoff.
  Future<void> start() async {
    await stop();
    _stopped = false;
    _failureCount = 0;
    _loopRunning = true;
    final loop = _connectLoop();
    _loopFuture = loop;
    try {
      await loop;
    } finally {
      if (identical(_loopFuture, loop)) {
        _loopFuture = null;
      }
      _loopRunning = false;
    }
  }

  /// Cancel reconnect timer, close SSE, and prevent further reconnects.
  Future<void> stop() async {
    _stopped = true;
    _wakeDelay();
    await _tearDownConnection();
    final loop = _loopFuture;
    if (loop != null) {
      try {
        await loop.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        // Loop should exit promptly once woken; don't hang forever.
      }
    }
    _failureCount = 0;
  }

  void _wakeDelay() {
    final c = _delayCompleter;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
  }

  Future<void> _tearDownConnection() async {
    await _sub?.cancel();
    _sub = null;
    _client?.close();
    _client = null;
  }

  Future<void> _sleep(Duration delay) async {
    if (_stopped || delay <= Duration.zero) return;
    final c = Completer<void>();
    _delayCompleter = c;
    final timer = Timer(delay, () {
      if (!c.isCompleted) c.complete();
    });
    try {
      await c.future;
    } finally {
      timer.cancel();
      if (identical(_delayCompleter, c)) {
        _delayCompleter = null;
      }
    }
  }

  Future<void> _connectLoop() async {
    while (!_stopped) {
      try {
        await _listenOnce();
        // Stream ended cleanly (server close / idle). Soft reconnect with
        // backoff only if still supposed to run — success already reset count.
        if (_stopped) break;
        if (_failureCount == 0) {
          // Brief pause after a healthy stream ends before reopening.
          await _sleep(const Duration(seconds: 1));
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[inventory-sse] $e');
        }
        if (_stopped) break;
        final delay = _delayForFailure(_failureCount);
        _failureCount += 1;
        if (kDebugMode) {
          debugPrint(
            '[inventory-sse] reconnect in ${delay.inMilliseconds}ms '
            '(failure #$_failureCount)',
          );
        }
        await _sleep(delay);
      }
    }
  }

  Future<void> _listenOnce() async {
    final reader = _accessTokenReader;
    final token =
        reader != null ? await reader() : await session.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('SSE skipped: no access token');
    }

    // Ensure only one HTTP client / subscription at a time.
    await _tearDownConnection();
    if (_stopped) return;

    final uri = Uri.parse('${config.apiBaseUrl}/events/inventory');
    _client = http.Client();
    final request = http.Request('GET', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';

    final response = await _client!.send(request).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('SSE connect timeout'),
    );
    if (_stopped) {
      await _tearDownConnection();
      return;
    }
    if (response.statusCode != 200) {
      await _tearDownConnection();
      throw StateError('SSE HTTP ${response.statusCode}');
    }

    // Successful open — reset backoff so the next drop starts short again.
    _failureCount = 0;

    final buffer = StringBuffer();
    final completer = Completer<void>();
    _sub = response.stream
        .transform(utf8.decoder)
        .listen(
          (chunk) {
            buffer.write(chunk);
            _drainSse(buffer);
          },
          onError: (Object e) {
            if (!completer.isCompleted) completer.completeError(e);
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );
    try {
      await completer.future;
    } finally {
      await _tearDownConnection();
    }
  }

  void _drainSse(StringBuffer buffer) {
    final text = buffer.toString();
    final parts = text.split('\n\n');
    if (parts.length < 2) return;
    buffer
      ..clear()
      ..write(parts.last);

    for (var i = 0; i < parts.length - 1; i++) {
      final block = parts[i].trim();
      if (block.isEmpty || block.startsWith(':')) continue;
      String? data;
      for (final line in block.split('\n')) {
        if (line.startsWith('data:')) {
          data = line.substring(5).trim();
        }
      }
      if (data == null || data.isEmpty) continue;
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          onEvent?.call(decoded);
        } else if (decoded is Map) {
          onEvent?.call(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
  }
}
