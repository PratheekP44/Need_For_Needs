import 'ble_log.dart';

/// Phase 31 — Collect BLE stage profiler (wall-clock from Collect press).
///
/// Logs elapsed and delta ms for every stage so we can see where time goes
/// without guessing.
class CollectBleProfiler {
  CollectBleProfiler() {
    _sw.start();
    mark('T0');
  }

  final Stopwatch _sw = Stopwatch();
  int _lastMs = 0;
  final List<({String stage, int atMs, int deltaMs})> _stages = [];

  int get elapsedMs => _sw.elapsedMilliseconds;

  void mark(String stage) {
    final atMs = _sw.elapsedMilliseconds;
    final deltaMs = atMs - _lastMs;
    _lastMs = atMs;
    _stages.add((stage: stage, atMs: atMs, deltaMs: deltaMs));
    BleLog.d('[Phase31] $stage t=${atMs}ms Δ=${deltaMs}ms');
  }

  int? deltaOf(String stagePrefix) {
    for (final s in _stages) {
      if (s.stage.startsWith(stagePrefix)) return s.deltaMs;
    }
    return null;
  }

  int? atOf(String stagePrefix) {
    for (final s in _stages) {
      if (s.stage.startsWith(stagePrefix)) return s.atMs;
    }
    return null;
  }

  /// Human-readable stage durations for the Phase 31 report.
  void report({required bool success, String? note}) {
    final scan = _span('SCAN_START', 'SCAN_STOP');
    final connect = _span('CONNECT_START', 'CONNECTED');
    final write = _span('WRITE_START', 'WRITE_COMPLETE');
    final response = _span('WRITE_COMPLETE', 'RESPONSE_RECEIVED');

    final buf = StringBuffer()
      ..writeln('════════ PHASE 31 COLLECT TIMING ════════')
      ..writeln('success=$success${note != null ? ' note=$note' : ''}')
      ..writeln('TOTAL: ${elapsedMs}ms')
      ..writeln('SCAN: ${scan ?? '—'}ms')
      ..writeln('CONNECT(+MTU+DISCOVERY+NOTIFY): ${connect ?? '—'}ms')
      ..writeln('WRITE: ${write ?? '—'}ms')
      ..writeln('RESPONSE: ${response ?? '—'}ms')
      ..writeln('(MTU/DISCOVERY/NOTIFY deltas: see post-connect pipeline report)');
    for (final s in _stages) {
      buf.writeln('  t=${s.atMs}ms Δ=${s.deltaMs}ms ${s.stage}');
    }
    buf.writeln('════════════════════════════════════════');
    for (final line in buf.toString().split('\n')) {
      if (line.isNotEmpty) BleLog.d(line);
    }
  }

  int? _span(String startPrefix, String endPrefix) {
    final a = atOf(startPrefix);
    final b = atOf(endPrefix);
    if (a == null || b == null) return null;
    return b - a;
  }
}
