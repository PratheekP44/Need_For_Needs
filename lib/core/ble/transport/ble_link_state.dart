/// Link-layer readiness flags (production parity with SmartAAP BleHandler).
///
/// These are transport-only; packet auth/handshake lives in [BleProtocol].
class BleLinkFlags {
  static const int none = 0;
  static const int error = 1;
  static const int busy = 2;
  static const int connected = 4;
  static const int mtuSet = 8;
  static const int servicesDiscovered = 16;
  static const int dataWritten = 32;
  static const int dataReceived = 64;
  static const int rssiReceived = 128;
  static const int notificationsEnabled = 256;
}

/// Snapshot of transport readiness for debug UI / diagnostics.
class BleLinkState {
  const BleLinkState({this.flags = BleLinkFlags.none, this.lastError});

  final int flags;
  final String? lastError;

  bool get hasError => (flags & BleLinkFlags.error) != 0;
  bool get isBusy => (flags & BleLinkFlags.busy) != 0;
  bool get isConnected => (flags & BleLinkFlags.connected) != 0;
  bool get mtuSet => (flags & BleLinkFlags.mtuSet) != 0;
  bool get servicesDiscovered =>
      (flags & BleLinkFlags.servicesDiscovered) != 0;
  bool get dataWritten => (flags & BleLinkFlags.dataWritten) != 0;
  bool get dataReceived => (flags & BleLinkFlags.dataReceived) != 0;
  bool get rssiReceived => (flags & BleLinkFlags.rssiReceived) != 0;
  bool get notificationsEnabled =>
      (flags & BleLinkFlags.notificationsEnabled) != 0;

  /// Ready for application writes (Java "BT Ready" equivalent).
  bool get isReady =>
      isConnected &&
      servicesDiscovered &&
      notificationsEnabled &&
      !hasError;

  BleLinkState copyWith({int? flags, String? lastError, bool clearError = false}) {
    return BleLinkState(
      flags: flags ?? this.flags,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  BleLinkState withFlag(int flag) => copyWith(flags: flags | flag);

  BleLinkState withoutFlag(int flag) => copyWith(flags: flags & ~flag);

  BleLinkState fail(String message) =>
      copyWith(flags: flags | BleLinkFlags.error, lastError: message);

  @override
  String toString() =>
      'BleLinkState(flags=0x${flags.toRadixString(16)}, error=$lastError)';
}
