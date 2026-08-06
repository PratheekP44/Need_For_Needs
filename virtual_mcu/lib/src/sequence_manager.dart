/// MCU-side inbound sequence tracking (detect gaps / duplicates).
class SequenceManager {
  SequenceManager({this.window = 64});

  final int window;
  final Set<int> _seen = {};
  int? lastSequence;
  int outbound = 1;

  int nextOutbound() {
    final v = outbound & 0xffff;
    outbound = (outbound + 1) & 0xffff;
    if (outbound == 0) outbound = 1;
    return v;
  }

  /// Returns false if duplicate within window.
  bool acceptInbound(int sequence) {
    final seq = sequence & 0xffff;
    if (_seen.contains(seq)) return false;
    _seen.add(seq);
    lastSequence = seq;
    if (_seen.length > window) {
      _seen.remove(_seen.first);
    }
    return true;
  }

  void reset() {
    _seen.clear();
    lastSequence = null;
    outbound = 1;
  }
}
