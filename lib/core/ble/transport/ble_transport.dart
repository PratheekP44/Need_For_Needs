import 'dart:typed_data';

import '../models/ble_device.dart';

/// Bluetooth adapter high-level state for UI providers.
enum BleAdapterState {
  unknown,
  unavailable,
  unauthorized,
  turningOn,
  on,
  turningOff,
  off,
}

/// Low-level BLE transport — no packet parsing or business logic.
abstract class BleTransport {
  Stream<BleAdapterState> get adapterStateStream;
  Stream<List<BleDevice>> get scanResultsStream;
  Stream<bool> get connectionStream;
  Stream<Uint8List> get notificationStream;
  Stream<int> get rssiStream;

  bool get isConnected;
  BleDevice? get connectedDevice;

  Future<void> ensurePermissions();
  Future<BleAdapterState> adapterState();

  /// Scan for nearby devices.
  ///
  /// When [stopOnTarget] is true, stop as soon as [BleDevice.isTargetLocker]
  /// matches (exact configured name / service UUID) — do not wait for timeout.
  Future<List<BleDevice>> startScan({
    required Duration timeout,
    String? namePrefix,
    bool stopOnTarget = false,
  });

  Future<void> stopScan();

  Future<void> connect(BleDevice device, {required Duration timeout});
  Future<void> disconnect();

  Future<int> requestMtu(int mtu);
  Future<void> discoverServices();
  Future<void> enableNotifications();

  Future<void> write(Uint8List bytes, {bool withoutResponse = false});
  Future<Uint8List?> read();

  Future<int?> readRssi();

  Future<void> dispose();
}
