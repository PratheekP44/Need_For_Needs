import 'package:flutter/foundation.dart';

/// Structured BLE diagnostics (scan → connect → GATT → TX/RX).
///
/// Mirrors the production logging intent of the SmartAAP [BleHandler]
/// without requiring Android Logcat / HandlerThreads.
class BleLog {
  BleLog._();

  static const String tag = 'CE-BLE';

  static void d(String message) {
    debugPrint('[$tag] $message');
  }

  static void e(String message, [Object? error]) {
    if (error == null) {
      debugPrint('[$tag] ERROR $message');
    } else {
      debugPrint('[$tag] ERROR $message :: $error');
    }
  }

  static void tx(String detail) => d('TX $detail');
  static void rx(String detail) => d('RX $detail');
  static void rssi(int value) => d('RSSI $value dBm');
}
