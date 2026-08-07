/// Central BLE configuration for Campus Essentials.
///
/// All GATT UUIDs and transport defaults live here — nowhere else.
///
/// Phase 13 — TI CC2340R5 GATT profile (firmware-provided).
/// Production link timings aligned with SmartAAP BleHandler patterns
/// (MTU 512 request, connect retries) without adopting that SDK's crypto.
library;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Immutable BLE stack configuration.
class BleConfig {
  const BleConfig({
    required this.serviceUuid,
    required this.writeCharacteristicUuid,
    required this.notifyCharacteristicUuid,
    required this.deviceNamePrefix,
    this.secondaryWriteCharacteristicUuid,
    this.targetDeviceName = 'LKRM-V2',
    this.scanTimeout = const Duration(seconds: 15),
    this.connectTimeout = const Duration(seconds: 10),
    this.desiredMtu = 512,
    this.autoReconnect = true,
    this.maxReconnectAttempts = 3,
    this.reconnectDelay = const Duration(milliseconds: 800),
    this.connectRetryAttempts = 3,
    this.discoverTimeout = const Duration(seconds: 8),
    this.writeTimeout = const Duration(seconds: 15),
    this.writeSpacing = Duration.zero,
    this.postConnectSettle = Duration.zero,
    this.postMtuSettle = Duration.zero,
    this.postDiscoverSettle = Duration.zero,
    this.postNotifySettle = Duration.zero,
    this.writeRetryAttempts = 3,
    this.rssiPollInterval = const Duration(seconds: 2),
    this.useVirtualMcuTransport = true,
    this.useMockTransport = false,
    this.protocolVersion = 1,
    this.commandCharacteristicMaxBytes = 100,
    this.statusCharacteristicMaxBytes = 16,
  });

  /// Primary locker GATT service UUID (CC2340R5).
  final Guid serviceUuid;

  /// Characteristic 1 — Phone → locker writes (commands). Max 100 bytes.
  final Guid writeCharacteristicUuid;

  /// Characteristic 4 — Locker → phone notifications (status). Max 16 bytes.
  final Guid notifyCharacteristicUuid;

  /// Optional second WRITE characteristic (firmware / SmartAAP C3).
  final Guid? secondaryWriteCharacteristicUuid;

  /// Exact advertised name used to highlight the target locker in debug scan.
  final String targetDeviceName;

  /// Advertised name prefix used while scanning.
  /// Empty string = no name filter.
  final String deviceNamePrefix;

  final Duration scanTimeout;
  final Duration connectTimeout;

  /// Requested ATT MTU (Java BleHandler uses 512; stack may negotiate lower).
  final int desiredMtu;
  final bool autoReconnect;
  final int maxReconnectAttempts;
  final Duration reconnectDelay;

  /// Fresh-connect attempts including GATT 133 retries.
  final int connectRetryAttempts;
  final Duration discoverTimeout;
  final Duration writeTimeout;

  /// Delay before each characteristic write.
  ///
  /// Java `sleep(100)` is between successive writes, not before the first
  /// AUTH after CCCD. Default **zero** so AUTH beats firmware idle timeout.
  final Duration writeSpacing;

  /// Optional settle after Connected before Request MTU.
  /// Default **zero** — Java proceeds on the Connected callback.
  final Duration postConnectSettle;

  /// Optional settle after MTU callback before Discover.
  /// Default **zero** — Java proceeds on `onMtuChanged`.
  final Duration postMtuSettle;

  /// Optional settle after discovery before Enable Notify.
  /// Default **zero** — Java proceeds on `onServicesDiscovered`.
  final Duration postDiscoverSettle;

  /// Optional settle after CCCD before AUTH write.
  /// Default **zero** — Java writes AUTH immediately after descriptor success.
  /// Non-zero values risk firmware idle disconnect (~5s).
  final Duration postNotifySettle;

  /// Retries for characteristic write on Android GATT 133.
  final int writeRetryAttempts;

  final Duration rssiPollInterval;

  /// Prefer [VirtualMCUTransport] (software CC2340 stand-in).
  final bool useVirtualMcuTransport;

  /// Legacy simple mock (when virtual MCU is off).
  final bool useMockTransport;

  /// Must match Phase 10 `PROTOCOL_VERSION`.
  final int protocolVersion;

  /// CC2340 Command characteristic declared length.
  final int commandCharacteristicMaxBytes;

  /// CC2340 Status characteristic declared length.
  final int statusCharacteristicMaxBytes;

  /// Development defaults — Virtual MCU ON (no hardware).
  factory BleConfig.development() => BleConfig(
        serviceUuid: Guid(cc2340ServiceUuid),
        writeCharacteristicUuid: Guid(cc2340CommandCharacteristicUuid),
        notifyCharacteristicUuid: Guid(cc2340StatusCharacteristicUuid),
        deviceNamePrefix: 'CE-LOCKER',
        useVirtualMcuTransport: true,
        useMockTransport: false,
        desiredMtu: 512,
      );

  /// Real Android BLE → TI CC2340R5 (FlutterBluePlus transport).
  factory BleConfig.hardware({
    String? serviceUuid,
    String? writeCharacteristicUuid,
    String? notifyCharacteristicUuid,
    String? secondaryWriteCharacteristicUuid,
    String deviceNamePrefix = '',
    String targetDeviceName = 'LKRM-V2',
  }) =>
      BleConfig(
        serviceUuid: Guid(serviceUuid ?? cc2340ServiceUuid),
        writeCharacteristicUuid:
            Guid(writeCharacteristicUuid ?? cc2340CommandCharacteristicUuid),
        notifyCharacteristicUuid:
            Guid(notifyCharacteristicUuid ?? cc2340StatusCharacteristicUuid),
        secondaryWriteCharacteristicUuid: Guid(
          secondaryWriteCharacteristicUuid ??
              cc2340SecondaryWriteCharacteristicUuid,
        ),
        deviceNamePrefix: deviceNamePrefix,
        targetDeviceName: targetDeviceName,
        scanTimeout: const Duration(seconds: 15),
        useVirtualMcuTransport: false,
        useMockTransport: false,
        desiredMtu: 512,
        // Allow ATT MTU-sized command frames (declared Char1 len is 100;
        // negotiated MTU may permit larger writes on real silicon).
        commandCharacteristicMaxBytes: 512,
        connectTimeout: const Duration(seconds: 10),
        connectRetryAttempts: 3,
        autoReconnect: true,
        postConnectSettle: Duration.zero,
        postMtuSettle: Duration.zero,
        postDiscoverSettle: Duration.zero,
        postNotifySettle: Duration.zero,
        writeRetryAttempts: 3,
        writeSpacing: Duration.zero,
      );

  BleConfig copyWith({
    Guid? serviceUuid,
    Guid? writeCharacteristicUuid,
    Guid? notifyCharacteristicUuid,
    Guid? secondaryWriteCharacteristicUuid,
    String? deviceNamePrefix,
    String? targetDeviceName,
    Duration? scanTimeout,
    Duration? connectTimeout,
    int? desiredMtu,
    bool? autoReconnect,
    int? maxReconnectAttempts,
    Duration? reconnectDelay,
    int? connectRetryAttempts,
    Duration? discoverTimeout,
    Duration? writeTimeout,
    Duration? writeSpacing,
    Duration? postConnectSettle,
    Duration? postMtuSettle,
    Duration? postDiscoverSettle,
    Duration? postNotifySettle,
    int? writeRetryAttempts,
    Duration? rssiPollInterval,
    bool? useVirtualMcuTransport,
    bool? useMockTransport,
    int? protocolVersion,
    int? commandCharacteristicMaxBytes,
    int? statusCharacteristicMaxBytes,
  }) {
    return BleConfig(
      serviceUuid: serviceUuid ?? this.serviceUuid,
      writeCharacteristicUuid:
          writeCharacteristicUuid ?? this.writeCharacteristicUuid,
      notifyCharacteristicUuid:
          notifyCharacteristicUuid ?? this.notifyCharacteristicUuid,
      secondaryWriteCharacteristicUuid: secondaryWriteCharacteristicUuid ??
          this.secondaryWriteCharacteristicUuid,
      deviceNamePrefix: deviceNamePrefix ?? this.deviceNamePrefix,
      targetDeviceName: targetDeviceName ?? this.targetDeviceName,
      scanTimeout: scanTimeout ?? this.scanTimeout,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      desiredMtu: desiredMtu ?? this.desiredMtu,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      maxReconnectAttempts:
          maxReconnectAttempts ?? this.maxReconnectAttempts,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      connectRetryAttempts:
          connectRetryAttempts ?? this.connectRetryAttempts,
      discoverTimeout: discoverTimeout ?? this.discoverTimeout,
      writeTimeout: writeTimeout ?? this.writeTimeout,
      writeSpacing: writeSpacing ?? this.writeSpacing,
      postConnectSettle: postConnectSettle ?? this.postConnectSettle,
      postMtuSettle: postMtuSettle ?? this.postMtuSettle,
      postDiscoverSettle: postDiscoverSettle ?? this.postDiscoverSettle,
      postNotifySettle: postNotifySettle ?? this.postNotifySettle,
      writeRetryAttempts: writeRetryAttempts ?? this.writeRetryAttempts,
      rssiPollInterval: rssiPollInterval ?? this.rssiPollInterval,
      useVirtualMcuTransport:
          useVirtualMcuTransport ?? this.useVirtualMcuTransport,
      useMockTransport: useMockTransport ?? this.useMockTransport,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      commandCharacteristicMaxBytes: commandCharacteristicMaxBytes ??
          this.commandCharacteristicMaxBytes,
      statusCharacteristicMaxBytes: statusCharacteristicMaxBytes ??
          this.statusCharacteristicMaxBytes,
    );
  }

  bool get isRealBle => !useVirtualMcuTransport && !useMockTransport;

  // ── TI CC2340R5 GATT profile (Phase 13) ──────────────────────────────
  // NOTE: SmartAAP BleHandler.java uses a different service/C1/C3/C4 set.
  // Campus Essentials Phase 10/13 keeps the CC2340 UUIDs below.
  static const String cc2340ServiceUuid =
      '3f43d273-e6d2-d4bf-a948-08de3193ed76';
  static const String cc2340CommandCharacteristicUuid =
      '3f43d273-e6d2-d4bf-a948-08de3293ed76';
  static const String cc2340StatusCharacteristicUuid =
      '3f43d273-e6d2-d4bf-a948-08de3393ed76';

  /// Second WRITE characteristic present on LKRM-V2 / CC2340 firmware.
  static const String cc2340SecondaryWriteCharacteristicUuid =
      '1e96e241-8684-41e2-bb58-5c1b25597afa';

  /// Reference-only SmartAAP UUIDs (not used by Campus Essentials firmware).
  static const String smartAapServiceUuid =
      '1B8420D8-7148-482D-A88B-B4715976F77B';
  static const String smartAapC1Uuid =
      'A9EFECF1-5493-4101-A144-3BA0F6B3175A';
  static const String smartAapC3Uuid =
      '1E96E241-8684-41E2-BB58-5C1B25597AFA';
  static const String smartAapC4Uuid =
      'B126896A-B0AF-4F26-B880-839A853E803E';
}
