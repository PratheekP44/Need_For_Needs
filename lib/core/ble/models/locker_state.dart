/// BLE / locker session state machine (phone-side).
enum LockerState {
  disconnected,
  scanning,
  connecting,
  connected,
  reconnecting,
  authenticating,
  authenticated,
  opening,
  waitingResponse,
  success,
  failure;

  bool get isTerminal =>
      this == LockerState.success || this == LockerState.failure;

  bool get isConnectedish =>
      this != LockerState.disconnected &&
      this != LockerState.scanning &&
      this != LockerState.connecting &&
      this != LockerState.reconnecting &&
      this != LockerState.failure;
}
