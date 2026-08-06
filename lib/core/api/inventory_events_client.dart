import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env_config.dart';
import 'api_client.dart';

/// Listens to `GET /events/inventory` (SSE) and notifies [onEvent].
class InventoryEventsClient {
  InventoryEventsClient({
    required this.session,
    required this.config,
    this.onEvent,
  });

  final SessionStore session;
  final EnvConfig config;
  final void Function(Map<String, dynamic> event)? onEvent;

  http.Client? _client;
  StreamSubscription<String>? _sub;
  bool _stopped = false;

  Future<void> start() async {
    _stopped = false;
    await _connectLoop();
  }

  Future<void> stop() async {
    _stopped = true;
    await _sub?.cancel();
    _sub = null;
    _client?.close();
    _client = null;
  }

  Future<void> _connectLoop() async {
    while (!_stopped) {
      try {
        await _listenOnce();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[inventory-sse] $e');
        }
      }
      if (_stopped) break;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  Future<void> _listenOnce() async {
    final token = await session.accessToken;
    if (token == null || token.isEmpty) {
      await Future<void>.delayed(const Duration(seconds: 2));
      return;
    }

    final uri = Uri.parse('${config.apiBaseUrl}/events/inventory');
    _client?.close();
    _client = http.Client();
    final request = http.Request('GET', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';

    final response = await _client!.send(request).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('SSE connect timeout'),
    );
    if (response.statusCode != 200) {
      throw StateError('SSE HTTP ${response.statusCode}');
    }

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
    await completer.future;
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
