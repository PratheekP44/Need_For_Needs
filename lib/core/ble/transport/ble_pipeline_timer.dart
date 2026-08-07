import 'ble_log.dart';

/// Millisecond pipeline stopwatch for Connect → … → first AUTH write.
///
/// Firmware idle timeout (~5s) is measured from [CONNECT_ESTABLISHED], not scan.
class BlePipelineTimer {
  BlePipelineTimer() : _started = DateTime.now();

  final DateTime _started;
  DateTime _last = DateTime.now();
  final List<({String stage, int atMs, int deltaMs})> _stages = [];

  int get elapsedMs =>
      DateTime.now().difference(_started).inMilliseconds;

  /// Mark a named stage. Returns elapsed ms since timer start.
  int mark(String stage) {
    final now = DateTime.now();
    final atMs = now.difference(_started).inMilliseconds;
    final deltaMs = now.difference(_last).inMilliseconds;
    _last = now;
    _stages.add((stage: stage, atMs: atMs, deltaMs: deltaMs));
    BleLog.d('TIMING t=${atMs}ms Δ=${deltaMs}ms stage=$stage');
    return atMs;
  }

  int? _at(String prefix) {
    for (final s in _stages) {
      if (s.stage.startsWith(prefix)) return s.atMs;
    }
    return null;
  }

  /// Dump timing table. Idle budget is from CONNECT_ESTABLISHED → first AUTH.
  void report({String? headline}) {
    final connectedAt = _at('CONNECT_ESTABLISHED') ?? 0;
    final notifyAt = _at('NOTIFY_ENABLED');
    final authAt = _at('FIRST_AUTH_WRITE_START') ??
        _at('FIRST_AUTH_WRITE_SUCCESS') ??
        _at('FIRST_AUTH_WRITE_FAILED');

    final buf = StringBuffer();
    buf.writeln('════════ BLE TIMING REPORT ════════');
    if (headline != null) buf.writeln(headline);
    buf.writeln('(t measured from CONNECT_BEGIN)');
    for (final s in _stages) {
      final sinceConnected = s.atMs - connectedAt;
      buf.writeln(
        't=${s.atMs}ms  Δ=${s.deltaMs}ms  '
        'since_connected=${sinceConnected}ms  ${s.stage}',
      );
    }
    if (authAt != null) {
      final idleUsed = authAt - connectedAt;
      buf.writeln('── Idle-timeout analysis ──');
      buf.writeln('CONNECT_ESTABLISHED at t=${connectedAt}ms');
      if (notifyAt != null) {
        buf.writeln(
          'NOTIFY_ENABLED at t=${notifyAt}ms '
          '(+${notifyAt - connectedAt}ms after connect)',
        );
        buf.writeln(
          'NOTIFY→AUTH gap=${authAt - notifyAt}ms '
          '(Java: ~0ms after CCCD callback)',
        );
      }
      buf.writeln(
        'FIRST_AUTH at t=${authAt}ms (+${idleUsed}ms after connect)',
      );
      buf.writeln('firmware_idle_budget≈5000ms');
      buf.writeln(
        idleUsed > 5000
            ? 'RESULT: AUTH AFTER idle budget — firmware likely '
                'already dropped the link ($idleUsed ms > 5000 ms)'
            : 'RESULT: AUTH within idle budget '
                '(margin=${5000 - idleUsed}ms)',
      );
    }
    buf.writeln('total_from_CONNECT_BEGIN=${elapsedMs}ms');
    buf.writeln('══════════════════════════════════');
    for (final line in buf.toString().split('\n')) {
      if (line.isNotEmpty) BleLog.d(line);
    }
  }
}
