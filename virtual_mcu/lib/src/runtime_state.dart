/// MCU runtime variables (mirrors future CC2340 debug table).
class McuRuntimeState {
  McuRuntimeState({
    required this.mcuId,
    required this.firmwareVersion,
    required this.lockerId,
    this.batteryLevel = 92,
    this.temperature = 28.5,
    this.rssi = -55,
  }) : bootedAt = DateTime.now();

  final String mcuId;
  final String firmwareVersion;
  final String lockerId;
  final DateTime bootedAt;

  bool bleConnected = false;
  bool authenticated = false;
  String? currentUser;
  String? currentOrder;
  String? currentLocker;
  String? currentBox;
  int batteryLevel;
  double temperature;
  int rssi;
  int heartbeatCounter = 0;
  int packetCounter = 0;
  int uptimeSeconds = 0;
  String? lastPacket;
  String? lastError;

  Map<String, Object?> toJson() => {
        'mcuId': mcuId,
        'firmwareVersion': firmwareVersion,
        'bleConnected': bleConnected,
        'authenticated': authenticated,
        'currentUser': currentUser,
        'currentOrder': currentOrder,
        'currentLocker': currentLocker ?? lockerId,
        'currentBox': currentBox,
        'batteryLevel': batteryLevel,
        'temperature': temperature,
        'rssi': rssi,
        'heartbeatCounter': heartbeatCounter,
        'packetCounter': packetCounter,
        'uptime': uptimeSeconds,
        'lastPacket': lastPacket,
        'lastError': lastError,
      };

  void resetSession() {
    authenticated = false;
    currentUser = null;
    currentOrder = null;
    currentBox = null;
    lastError = null;
  }
}
