/// Outbound sequence numbers (uint16, 0 reserved).
class SequenceManager {
  SequenceManager({int initial = 1, this.window = 32})
      : _nextOutbound = initial;

  int _nextOutbound;
  final int window;
  final Set<int> _recentInbound = <int>{};
  int? lastInbound;

  /// Allocate next outbound sequence number.
  int next() {
    final value = _nextOutbound & 0xffff;
    _nextOutbound = (_nextOutbound + 1) & 0xffff;
    if (_nextOutbound == 0) {
      _nextOutbound = 1;
    }
    return value;
  }

  /// Record inbound sequence; rejects duplicates within [window].
  ({bool accepted, bool duplicate}) acceptInbound(int sequenceNumber) {
    final seq = sequenceNumber & 0xffff;
    if (_recentInbound.contains(seq)) {
      return (accepted: false, duplicate: true);
    }
    _recentInbound.add(seq);
    lastInbound = seq;
    if (_recentInbound.length > window) {
      _recentInbound.remove(_recentInbound.first);
    }
    return (accepted: true, duplicate: false);
  }

  void reset() {
    _nextOutbound = 1;
    _recentInbound.clear();
    lastInbound = null;
  }
}
