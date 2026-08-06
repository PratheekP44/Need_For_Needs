/// Runtime MCU debug log (firmware-style event table).
class RuntimeLogger {
  final List<RuntimeLogEntry> _entries = [];

  List<RuntimeLogEntry> get entries => List.unmodifiable(_entries);

  void log({
    required String event,
    String? packet,
    String? box,
    String? door,
    String? lock,
    String? result,
    Map<String, Object?>? extra,
  }) {
    _entries.add(
      RuntimeLogEntry(
        timestamp: DateTime.now(),
        event: event,
        packet: packet,
        box: box,
        door: door,
        lock: lock,
        result: result,
        extra: extra,
      ),
    );
    if (_entries.length > 500) {
      _entries.removeRange(0, _entries.length - 500);
    }
  }

  void clear() => _entries.clear();

  List<Map<String, Object?>> toTable() =>
      _entries.map((e) => e.toJson()).toList();
}

class RuntimeLogEntry {
  RuntimeLogEntry({
    required this.timestamp,
    required this.event,
    this.packet,
    this.box,
    this.door,
    this.lock,
    this.result,
    this.extra,
  });

  final DateTime timestamp;
  final String event;
  final String? packet;
  final String? box;
  final String? door;
  final String? lock;
  final String? result;
  final Map<String, Object?>? extra;

  Map<String, Object?> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'event': event,
        'packet': packet,
        'box': box,
        'door': door,
        'lock': lock,
        'result': result,
        ...?extra,
      };
}
