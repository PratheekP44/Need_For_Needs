import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/ble_config.dart';
import '../models/ble_device.dart';
import 'ble_link_state.dart';
import 'ble_log.dart';
import 'ble_pipeline_timer.dart';
import 'ble_transport.dart';

/// Snapshot of a discovered GATT service (debug / BLE Test screen).
class GattServiceInfo {
  const GattServiceInfo({
    required this.uuid,
    required this.characteristics,
  });

  final String uuid;
  final List<GattCharacteristicInfo> characteristics;
}

/// Snapshot of a discovered GATT characteristic.
class GattCharacteristicInfo {
  const GattCharacteristicInfo({
    required this.uuid,
    required this.properties,
    this.isCommand = false,
    this.isStatus = false,
    this.isSecondaryWrite = false,
  });

  final String uuid;
  final String properties;
  final bool isCommand;
  final bool isStatus;
  final bool isSecondaryWrite;
}

/// Which write characteristic to use (Java C1 token vs C3 command).
enum BleWriteTarget { c1, c3 }

/// Real BLE transport backed by `flutter_blue_plus` for TI CC2340R5.
///
/// Production hardening inspired by SmartAAP [BleHandler] (connect retries,
/// MTU 512, write serialization, link flags, CCCD notify, RSSI, logging)
/// while keeping [BleProtocol] / Phase 10 packet format unchanged.
class FlutterBlueTransport implements BleTransport {
  FlutterBlueTransport({required this.config});

  final BleConfig config;

  final _adapterController =
      StreamController<BleAdapterState>.broadcast();
  final _scanController = StreamController<List<BleDevice>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _notificationController = StreamController<Uint8List>.broadcast();
  final _rssiController = StreamController<int>.broadcast();
  final _linkStateController = StreamController<BleLinkState>.broadcast();

  final Map<String, BleDevice> _seen = {};
  final Queue<_WriteJob> _writeQueue = Queue<_WriteJob>();
  bool _writePumpRunning = false;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _secondaryWriteChar;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  Timer? _rssiTimer;
  bool _connected = false;
  BleLinkState _link = const BleLinkState();

  /// Last negotiated MTU (ATT).
  int? lastMtu;

  /// When the current connection became active.
  DateTime? connectedAt;

  /// Raw TX / RX byte-array counters (transport level).
  int txPacketCount = 0;
  int rxPacketCount = 0;

  /// Last GATT discovery snapshot for the BLE Debug screen.
  List<GattServiceInfo> discoveredServices = const [];

  /// Live link flags (CONNECTED / MTU_SET / SERVICES_DISCOVERED / …).
  BleLinkState get linkState => _link;
  Stream<BleLinkState> get linkStateStream => _linkStateController.stream;

  bool get hasCommandCharacteristic => _writeChar != null;
  bool get hasStatusCharacteristic => _notifyChar != null;

  /// Secondary WRITE characteristic found during last GATT discovery.
  bool hasSecondaryWriteCharacteristic = false;

  /// Pipeline stopwatch (set by [ConnectionManager] for timing reports).
  BlePipelineTimer? pipelineTimer;

  bool _firstAuthWriteLogged = false;

  /// Pipeline status strings for the BLE Debug screen.
  bool pipelineConnected = false;
  bool pipelineServicesFound = false;
  bool pipelineCharacteristicsFound = false;
  bool pipelineNotifyEnabled = false;

  static final Guid _cccdUuid = Guid('00002902-0000-1000-8000-00805f9b34fb');

  @override
  Stream<BleAdapterState> get adapterStateStream => _adapterController.stream;

  @override
  Stream<List<BleDevice>> get scanResultsStream => _scanController.stream;

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  Stream<Uint8List> get notificationStream => _notificationController.stream;

  @override
  Stream<int> get rssiStream => _rssiController.stream;

  @override
  bool get isConnected => _connected;

  @override
  BleDevice? get connectedDevice {
    final d = _device;
    if (d == null) return null;
    return BleDevice(id: d.remoteId.str, name: d.platformName);
  }

  void _setLink(BleLinkState next) {
    _link = next;
    if (!_linkStateController.isClosed) {
      _linkStateController.add(next);
    }
  }

  void _setFlag(int flag) => _setLink(_link.withFlag(flag));
  void _clearFlag(int flag) => _setLink(_link.withoutFlag(flag));
  void _fail(String message) {
    BleLog.e(message);
    _setLink(_link.fail(message));
  }

  @override
  Future<void> ensurePermissions() async {
    if (kIsWeb) {
      throw StateError('Real BLE is not supported on web — use Virtual MCU');
    }

    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];
    if (Platform.isAndroid) {
      // Declared for Android ≤11 BLE scan + nearby distances; not required to
      // *succeed* on Android 12+ when BLUETOOTH_SCAN uses neverForLocation.
      permissions.add(Permission.locationWhenInUse);
    }

    BleLog.d('Permission check BEFORE request:');
    for (final p in permissions) {
      final s = await p.status;
      BleLog.d('  ${p.toString()} => $s');
    }

    final statuses = await permissions.request();
    BleLog.d('Permission check AFTER request:');
    final deniedNames = <String>[];
    for (final entry in statuses.entries) {
      BleLog.d('  ${entry.key} => ${entry.value}');
      if (entry.value.isDenied ||
          entry.value.isPermanentlyDenied ||
          entry.value.isRestricted) {
        deniedNames.add('${entry.key}: ${entry.value}');
      }
    }

    final scanStatus = statuses[Permission.bluetoothScan];
    final connectStatus = statuses[Permission.bluetoothConnect];
    final locationStatus = statuses[Permission.locationWhenInUse];

    final scanOk = scanStatus?.isGranted == true ||
        scanStatus?.isLimited == true;
    final connectOk = connectStatus?.isGranted == true ||
        connectStatus?.isLimited == true;
    final locationOk = locationStatus?.isGranted == true ||
        locationStatus?.isLimited == true;

    // On Android 12+ bluetoothScan/Connect are the real gates.
    // On older APIs bluetoothScan may auto-grant; location is required.
    final permanentlyDeniedBt = (scanStatus?.isPermanentlyDenied ?? false) ||
        (connectStatus?.isPermanentlyDenied ?? false);

    if (permanentlyDeniedBt) {
      BleLog.e(
        'BT permissions permanently denied: ${deniedNames.join(', ')}',
      );
      await openAppSettings();
      throw StateError(
        'Bluetooth permissions permanently denied — enable Nearby devices / '
        'Bluetooth in Settings. Denied: ${deniedNames.join(', ')}',
      );
    }

    if (!scanOk || !connectOk) {
      // Fallback for Android ≤11 where bluetooth* permissions may not apply.
      if (Platform.isAndroid && locationOk && !scanOk) {
        BleLog.d(
          'BT_SCAN not granted but LOCATION granted — proceeding (Android ≤11)',
        );
        return;
      }
      final detail = deniedNames.isEmpty
          ? 'BLUETOOTH_SCAN=$scanStatus BLUETOOTH_CONNECT=$connectStatus'
          : deniedNames.join(', ');
      BleLog.e('Required Bluetooth permissions missing: $detail');
      throw StateError(
        'Bluetooth permissions not granted. Denied: $detail',
      );
    }

    if (Platform.isAndroid && !locationOk) {
      BleLog.d(
        'LOCATION not granted (ok on Android 12+ with neverForLocation). '
        'status=$locationStatus',
      );
    }
    BleLog.d('Permissions OK for BLE scan (scan=$scanOk connect=$connectOk)');
  }

  @override
  Future<BleAdapterState> adapterState() async {
    _adapterSub ??= FlutterBluePlus.adapterState.listen((state) {
      _adapterController.add(_mapAdapter(state));
    });
    final state = await FlutterBluePlus.adapterState.first;
    final mapped = _mapAdapter(state);
    _adapterController.add(mapped);
    return mapped;
  }

  BleAdapterState _mapAdapter(BluetoothAdapterState state) {
    switch (state) {
      case BluetoothAdapterState.unknown:
        return BleAdapterState.unknown;
      case BluetoothAdapterState.unavailable:
        return BleAdapterState.unavailable;
      case BluetoothAdapterState.unauthorized:
        return BleAdapterState.unauthorized;
      case BluetoothAdapterState.turningOn:
        return BleAdapterState.turningOn;
      case BluetoothAdapterState.on:
        return BleAdapterState.on;
      case BluetoothAdapterState.turningOff:
        return BleAdapterState.turningOff;
      case BluetoothAdapterState.off:
        return BleAdapterState.off;
    }
  }

  bool _guidEquals(Guid a, Guid b) =>
      a.str.toLowerCase() == b.str.toLowerCase();

  Future<void> _checkBtEnabled() async {
    final adapter = await adapterState();
    if (adapter != BleAdapterState.on) {
      throw StateError('BT_NOT_ENABLED — turn on Bluetooth');
    }
  }

  bool _isTargetAdvertisement({
    required String name,
    required List<Guid> advertisedServices,
  }) {
    final targetName = config.targetDeviceName.trim();
    if (targetName.isNotEmpty &&
        name.toUpperCase() == targetName.toUpperCase()) {
      return true;
    }
    return advertisedServices.any((u) => _guidEquals(u, config.serviceUuid));
  }

  String _hexBytes(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

  List<String> _manufacturerHex(Map<int, List<int>> data) {
    return data.entries.map((e) {
      final id = e.key.toRadixString(16).padLeft(4, '0');
      return '0x$id:${_hexBytes(e.value)}';
    }).toList();
  }

  void _logScanResult(ScanResult r, String name, bool isTarget) {
    final adv = r.advertisementData;
    final mfg = _manufacturerHex(adv.manufacturerData);
    final msdRaw = adv.msd.map(_hexBytes).toList();
    final uuids = adv.serviceUuids.map((u) => u.str).toList();
    BleLog.d(
      'SCAN_CB'
      ' name="${name.isEmpty ? '(none)' : name}"'
      ' id=${r.device.remoteId.str}'
      ' rssi=${r.rssi}'
      ' connectable=${adv.connectable}'
      ' target=$isTarget'
      ' services=$uuids'
      ' mfg=$mfg'
      ' msdRaw=$msdRaw',
    );
  }

  @override
  Future<List<BleDevice>> startScan({
    required Duration timeout,
    String? namePrefix,
  }) async {
    // namePrefix intentionally ignored during debug — show ALL BLE devices.
    // Re-introduce production filters only after discovery is proven.
    await ensurePermissions();
    await _checkBtEnabled();
    final scanFor = timeout < const Duration(seconds: 15)
        ? const Duration(seconds: 15)
        : timeout;
    BleLog.d(
      'Scan start UNFILTERED timeout=${scanFor.inSeconds}s '
      'mode=lowLatency continuousUpdates=true '
      '(debug: no UUID/name/MSD/RSSI filters)',
    );

    _seen.clear();
    await _scanSub?.cancel();
    if (FlutterBluePlus.isScanningNow) {
      BleLog.d('Stopping previous scan before restart');
      await FlutterBluePlus.stopScan();
    }

    _scanSub = FlutterBluePlus.scanResults.listen(
      (results) {
        for (final r in results) {
          final name = r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : r.device.platformName;
          final serviceUuids =
              r.advertisementData.serviceUuids.map((u) => u.str).toList();
          final isTarget = _isTargetAdvertisement(
            name: name,
            advertisedServices: r.advertisementData.serviceUuids,
          );
          _logScanResult(r, name, isTarget);

          final device = BleDevice(
            id: r.device.remoteId.str,
            name: name.isEmpty ? '(unnamed) ${r.device.remoteId.str}' : name,
            rssi: r.rssi,
            advertisementName: r.advertisementData.advName,
            isConnectable: r.advertisementData.connectable,
            manufacturerDataHex:
                _manufacturerHex(r.advertisementData.manufacturerData),
            serviceUuids: serviceUuids,
            isTargetLocker: isTarget,
          );
          _seen[device.id] = device;
        }
        final sorted = _seen.values.toList()
          ..sort((a, b) {
            if (a.isTargetLocker != b.isTargetLocker) {
              return a.isTargetLocker ? -1 : 1;
            }
            return (b.rssi ?? -999).compareTo(a.rssi ?? -999);
          });
        _scanController.add(sorted);
      },
      onError: (Object e, StackTrace st) {
        BleLog.e('scanResults stream error', e);
      },
      onDone: () {
        BleLog.d('scanResults stream done');
      },
    );

    try {
      // CRITICAL: no withServices / withNames / withMsd filters.
      // Android ScanFilter on service UUID was hiding every device that does
      // not advertise 3F43… in the ADV packet (LKRM-V2 may only send MSD).
      await FlutterBluePlus.startScan(
        timeout: scanFor,
        continuousUpdates: true,
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: false,
        androidCheckLocationServices: false,
      );
      BleLog.d('FlutterBluePlus.startScan invoked isScanningNow='
          '${FlutterBluePlus.isScanningNow}');
    } catch (e) {
      BleLog.e('FlutterBluePlus.startScan failed', e);
      await _scanSub?.cancel();
      _scanSub = null;
      rethrow;
    }

    // Wait until FBP timeout stops scanning, with a hard safety cap so the
    // BLE Debug spinner can never spin forever.
    try {
      await FlutterBluePlus.isScanning
          .where((scanning) => scanning == false)
          .first
          .timeout(scanFor + const Duration(seconds: 3));
    } on TimeoutException {
      BleLog.e('Scan wait timed out — forcing stopScan');
      await stopScan();
    } catch (e) {
      BleLog.e('Scan wait error', e);
      await stopScan();
    }
    await stopScan();

    final sorted = _seen.values.toList()
      ..sort((a, b) {
        if (a.isTargetLocker != b.isTargetLocker) {
          return a.isTargetLocker ? -1 : 1;
        }
        return (b.rssi ?? -999).compareTo(a.rssi ?? -999);
      });
    final targets = sorted.where((d) => d.isTargetLocker).toList();
    BleLog.d(
      'Scan done total=${sorted.length} targets=${targets.length} '
      'targetNames=${targets.map((d) => d.name).toList()}',
    );
    for (final d in targets) {
      BleLog.d(
        'TARGET_HIT name=${d.name} id=${d.id} rssi=${d.rssi} '
        'services=${d.serviceUuids} mfg=${d.manufacturerDataHex}',
      );
    }
    return sorted;
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
  }

  /// Android GATT status 133 (generic failure) — retry like Java BleHandler.
  bool _isGatt133(Object error) {
    final text = error.toString();
    return text.contains('133') ||
        text.toLowerCase().contains('status=133') ||
        text.toLowerCase().contains('gatt_error');
  }

  @override
  Future<void> connect(BleDevice device, {required Duration timeout}) async {
    await stopScan();
    await _checkBtEnabled();
    BleLog.d('Connect id=${device.id} name=${device.name}');
    pipelineConnected = false;
    pipelineServicesFound = false;
    pipelineCharacteristicsFound = false;
    pipelineNotifyEnabled = false;
    _firstAuthWriteLogged = false;
    hasSecondaryWriteCharacteristic = false;

    final remote = BluetoothDevice.fromId(device.id);
    _device = remote;
    await _connSub?.cancel();
    _connSub = remote.connectionState.listen((state) {
      final connected = state == BluetoothConnectionState.connected;
      _connected = connected;
      if (connected) {
        _setFlag(BleLinkFlags.connected);
        _clearFlag(BleLinkFlags.error);
      } else {
        _clearFlag(BleLinkFlags.connected);
        _clearFlag(BleLinkFlags.mtuSet);
        _clearFlag(BleLinkFlags.servicesDiscovered);
        _clearFlag(BleLinkFlags.notificationsEnabled);
        _stopRssiPolling();
        final reason = remote.disconnectReason;
        if (reason != null) {
          BleLog.d(
            'Disconnected code=${reason.code} desc=${reason.description}',
          );
        }
        connectedAt = null;
      }
      _connectionController.add(connected);
    });

    Object? lastError;
    final maxAttempts = config.connectRetryAttempts;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _setFlag(BleLinkFlags.busy);
        await remote.connect(
          license: License.nonprofit,
          timeout: timeout,
          mtu: null,
          autoConnect: false,
        );
        _connected = true;
        connectedAt = DateTime.now();
        pipelineConnected = true;
        _setFlag(BleLinkFlags.connected);
        _clearFlag(BleLinkFlags.busy);
        _connectionController.add(true);
        BleLog.d('Connected attempt=$attempt');
        BleLog.d('PIPELINE Connected=YES');

        // Java: CONNECTION_PRIORITY_HIGH after connect (Android only).
        if (!kIsWeb && Platform.isAndroid) {
          try {
            await remote.requestConnectionPriority(
              connectionPriorityRequest: ConnectionPriority.high,
            );
            BleLog.d('Connection priority HIGH');
          } catch (e) {
            BleLog.d('Connection priority skipped: $e');
          }
        }

        // Do NOT start RSSI here — concurrent GATT ops during
        // MTU/discover/notify/first-write cause Android status 133.
        return;
      } catch (e) {
        lastError = e;
        final is133 = _isGatt133(e) ||
            (remote.disconnectReason?.code == 133);
        BleLog.e('Connect attempt $attempt/$maxAttempts failed', e);
        if (attempt < maxAttempts && is133) {
          BleLog.d('GATT 133 — retrying after ${config.reconnectDelay}');
          await Future<void>.delayed(config.reconnectDelay);
          try {
            await remote.disconnect();
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 400));
          continue;
        }
        if (attempt < maxAttempts) {
          await Future<void>.delayed(config.reconnectDelay);
          continue;
        }
      }
    }

    _clearFlag(BleLinkFlags.busy);
    _fail('Connect Fail: $lastError');
    throw StateError('Connect Fail after $maxAttempts attempts: $lastError');
  }

  void _startRssiPolling() {
    _rssiTimer?.cancel();
    final interval = config.rssiPollInterval;
    if (interval <= Duration.zero) return;
    _rssiTimer = Timer.periodic(interval, (_) async {
      try {
        await readRssi();
      } catch (_) {}
    });
  }

  /// Called by [ConnectionManager] only after notify CCCD succeeds.
  void startRssiPollingAfterReady() {
    if (!_link.notificationsEnabled || !_connected) {
      BleLog.d('RSSI polling skipped — link not ready');
      return;
    }
    BleLog.d('RSSI polling start (post-pipeline)');
    _startRssiPolling();
  }

  void _stopRssiPolling() {
    _rssiTimer?.cancel();
    _rssiTimer = null;
  }

  @override
  Future<void> disconnect() async {
    BleLog.d('Disconnect');
    _stopRssiPolling();
    // Drain write queue with errors so waiters don't hang.
    while (_writeQueue.isNotEmpty) {
      final job = _writeQueue.removeFirst();
      if (!job.completer.isCompleted) {
        job.completer.completeError(StateError('Disconnected'));
      }
    }
    await _notifySub?.cancel();
    _notifySub = null;
    final d = _device;
    if (d != null) {
      try {
        await d.disconnect();
      } catch (_) {}
    }
    _writeChar = null;
    _notifyChar = null;
    _secondaryWriteChar = null;
    discoveredServices = const [];
    lastMtu = null;
    connectedAt = null;
    _connected = false;
    hasSecondaryWriteCharacteristic = false;
    pipelineConnected = false;
    pipelineServicesFound = false;
    pipelineCharacteristicsFound = false;
    pipelineNotifyEnabled = false;
    _firstAuthWriteLogged = false;
    _setLink(const BleLinkState());
    _connectionController.add(false);
  }

  @override
  Future<int> requestMtu(int mtu) async {
    final d = _device;
    if (d == null) return 23;
    // Java requests 512; FBP applies ~350ms predelay internally.
    final requested = mtu < 23 ? 23 : mtu;
    BleLog.d('PIPELINE RequestMTU $requested (await callback)');
    final timer = pipelineTimer;
    // FBP default predelay=0.35s avoids Android auto-MTU race (required).
    // Do not add extra settles on top — idle budget is ~5s.
    try {
      final negotiated = await d.requestMtu(requested, predelay: 0.35);
      lastMtu = negotiated;
      _setFlag(BleLinkFlags.mtuSet);
      BleLog.d(
        'PIPELINE WaitMtuCallback done negotiated=$negotiated '
        't=${timer?.elapsedMs}ms',
      );
      return negotiated;
    } catch (e) {
      BleLog.d('MTU request failed (using fallback): $e');
      lastMtu ??= 23;
      _setFlag(BleLinkFlags.mtuSet);
      return lastMtu!;
    }
  }

  @override
  Future<void> discoverServices() async {
    final d = _device;
    if (d == null) throw StateError('Not connected');
    BleLog.d('Discover services');
    final services = await d
        .discoverServices()
        .timeout(config.discoverTimeout, onTimeout: () {
      throw TimeoutException(
        'Service discovery timed out after ${config.discoverTimeout}',
      );
    });

    BluetoothCharacteristic? write;
    BluetoothCharacteristic? notify;
    BluetoothCharacteristic? secondaryWrite;
    final snapshot = <GattServiceInfo>[];
    var serviceFound = false;
    final secondaryUuid = config.secondaryWriteCharacteristicUuid;

    for (final s in services) {
      final isTarget = _guidEquals(s.uuid, config.serviceUuid);
      if (isTarget) serviceFound = true;
      final chars = <GattCharacteristicInfo>[];
      for (final c in s.characteristics) {
        final isCommand = _guidEquals(c.uuid, config.writeCharacteristicUuid);
        final isStatus = _guidEquals(c.uuid, config.notifyCharacteristicUuid);
        final isSecondary = secondaryUuid != null &&
            _guidEquals(c.uuid, secondaryUuid);
        if (isCommand) write = c;
        if (isStatus) notify = c;
        if (isSecondary) secondaryWrite = c;
        chars.add(
          GattCharacteristicInfo(
            uuid: c.uuid.str,
            properties: _propsLabel(c.properties),
            isCommand: isCommand,
            isStatus: isStatus,
            isSecondaryWrite: isSecondary,
          ),
        );
        BleLog.d(
          'GATT char service=${s.uuid.str} char=${c.uuid.str} '
          '${_propsLabel(c.properties)}'
          '${isCommand ? ' [WRITE/CMD]' : ''}'
          '${isSecondary ? ' [WRITE/SEC]' : ''}'
          '${isStatus ? ' [NOTIFY]' : ''}',
        );
      }
      snapshot.add(
        GattServiceInfo(uuid: s.uuid.str, characteristics: chars),
      );
    }
    discoveredServices = snapshot;
    pipelineServicesFound = serviceFound;
    hasSecondaryWriteCharacteristic = secondaryWrite != null;
    BleLog.d(
      'PIPELINE Services Found=${serviceFound ? 'YES' : 'NO'} '
      '(looking for ${config.serviceUuid.str})',
    );

    if (!serviceFound) {
      _fail('BT No Services — missing ${config.serviceUuid.str}');
      throw StateError(
        'BT No Services — required service ${config.serviceUuid.str} not found',
      );
    }
    if (write == null || notify == null) {
      pipelineCharacteristicsFound = false;
      _fail(
        'BT Bad Service — Char1=${write != null} Char4=${notify != null} '
        'SecWrite=${secondaryWrite != null}',
      );
      throw StateError(
        'BT Bad Service — '
        'command(Char1)=${write != null} status(Char4)=${notify != null} '
        'secondaryWrite=${secondaryWrite != null}',
      );
    }
    // Secondary WRITE is expected on LKRM-V2 but not required for notify path.
    if (secondaryUuid != null && secondaryWrite == null) {
      BleLog.d(
        'Secondary WRITE ${secondaryUuid.str} not found '
        '(continuing — command+notify present)',
      );
    }
    _writeChar = write;
    _notifyChar = notify;
    _secondaryWriteChar = secondaryWrite;
    pipelineCharacteristicsFound = true;
    _setFlag(BleLinkFlags.servicesDiscovered);
    BleLog.d(
      'PIPELINE Characteristics Found=YES '
      'C1=${write.uuid.str} C4=${notify.uuid.str} '
      'C3=${secondaryWrite?.uuid.str ?? 'missing'}',
    );
  }

  String _propsLabel(CharacteristicProperties p) {
    final parts = <String>[];
    if (p.read) parts.add('READ');
    if (p.write) parts.add('WRITE');
    if (p.writeWithoutResponse) parts.add('WRITE_NO_RESP');
    if (p.notify) parts.add('NOTIFY');
    if (p.indicate) parts.add('INDICATE');
    return parts.isEmpty ? 'NONE' : parts.join('|');
  }

  @override
  Future<void> enableNotifications() async {
    final c = _notifyChar;
    if (c == null) throw StateError('Status characteristic (Char 4 / C4) missing');
    if (!c.properties.notify && !c.properties.indicate) {
      throw StateError(
        'Status characteristic does not support NOTIFY/INDICATE',
      );
    }

    BleLog.d('PIPELINE EnableNotifyC4 uuid=${c.uuid.str}');
    // FBP awaits onDescriptorWritten for CCCD 0x2902 — Java parity.
    await c.setNotifyValue(true);

    try {
      final descriptors = c.descriptors;
      final cccd = descriptors.where((d) => _guidEquals(d.uuid, _cccdUuid));
      if (cccd.isEmpty) {
        BleLog.d('CCCD 0x2902 not listed — setNotifyValue completed anyway');
      } else {
        BleLog.d('CCCD 0x2902 present — descriptor write success awaited');
      }
    } catch (e) {
      BleLog.d('CCCD check skipped: $e');
    }

    await _notifySub?.cancel();
    _notifySub = c.onValueReceived.listen((value) {
      rxPacketCount += 1;
      _setFlag(BleLinkFlags.dataReceived);
      final bytes = Uint8List.fromList(value);
      BleLog.rx('${bytes.length}B ${_hexPreview(bytes)}');
      _notificationController.add(bytes);
    });
    _setFlag(BleLinkFlags.notificationsEnabled);
    pipelineNotifyEnabled = true;
    BleLog.d('BT Ready (notifications on)');
    BleLog.d('PIPELINE Notify Enabled=YES (descriptor write success)');
  }

  void _logWriteDiagnostics({
    required BluetoothCharacteristic c,
    required Uint8List bytes,
    required String role,
    required bool withoutResponse,
  }) {
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    BleLog.d('── WRITE PREFLIGHT ──────────────────────────────');
    BleLog.d('Connected state: $_connected (link=${_link.isConnected})');
    BleLog.d('MTU: ${lastMtu ?? 'not negotiated'}');
    BleLog.d('Current characteristic UUID: ${c.uuid.str}');
    BleLog.d('Characteristic properties: ${_propsLabel(c.properties)}');
    BleLog.d('Characteristic used: $role');
    BleLog.d('Services discovered: $pipelineServicesFound '
        '(count=${discoveredServices.length})');
    for (final s in discoveredServices) {
      BleLog.d('  Service ${s.uuid}');
      for (final ch in s.characteristics) {
        BleLog.d('    ${ch.uuid} ${ch.properties}'
            '${ch.isCommand ? ' [C1]' : ''}'
            '${ch.isSecondaryWrite ? ' [C3]' : ''}'
            '${ch.isStatus ? ' [C4]' : ''}');
      }
    }
    BleLog.d('Notification enabled: $pipelineNotifyEnabled '
        '(flag=${_link.notificationsEnabled})');
    BleLog.d('Link ready: ${_link.isReady}');
    BleLog.d('Packet length: ${bytes.length}');
    BleLog.d('Packet HEX: $hex');
    BleLog.d('Write type: ${withoutResponse ? 'WRITE_NO_RESP' : 'WRITE'}');
    BleLog.d('────────────────────────────────────────────────');
  }

  @override
  Future<void> write(Uint8List bytes, {bool withoutResponse = false}) async {
    await writeTo(BleWriteTarget.c1, bytes, withoutResponse: withoutResponse);
  }

  /// Write to C1 (AUTH / Phase 10) or C3 (command) — Java dual-char path.
  Future<void> writeTo(
    BleWriteTarget target,
    Uint8List bytes, {
    bool withoutResponse = false,
  }) async {
    if (!_connected) throw StateError('Not connected');
    if (!_link.notificationsEnabled || !pipelineNotifyEnabled) {
      throw StateError(
        'Write blocked — notifications not enabled yet '
        '(Java: wait descriptor write before AUTH). '
        'notify=$pipelineNotifyEnabled link=${_link.notificationsEnabled}',
      );
    }
    if (!_link.servicesDiscovered || !pipelineCharacteristicsFound) {
      throw StateError('Write blocked — services not discovered');
    }

    final c = switch (target) {
      BleWriteTarget.c1 => _writeChar,
      BleWriteTarget.c3 => _secondaryWriteChar,
    };
    if (c == null) {
      throw StateError(
        target == BleWriteTarget.c1
            ? 'C1 write characteristic missing'
            : 'C3 command characteristic missing',
      );
    }

    final negotiatedPayload =
        (lastMtu != null && lastMtu! > 3) ? lastMtu! - 3 : 20;
    final declaredMax = config.commandCharacteristicMaxBytes;
    final hardMax =
        negotiatedPayload < declaredMax ? negotiatedPayload : declaredMax;
    if (bytes.length > hardMax) {
      throw StateError(
        'Packet ${bytes.length} bytes exceeds write max ($hardMax) '
        'mtu=${lastMtu ?? 'null'} declaredMax=$declaredMax — '
        'GATT would fail; aborting before writeCharacteristic',
      );
    }
    if (bytes.length > 100) {
      BleLog.d(
        'WARNING packet ${bytes.length}B > firmware Char1 declared 100B '
        '(proceeding if MTU allows; watch for GATT 133)',
      );
    }

    final canWrite = c.properties.write;
    final canWriteNoResp = c.properties.writeWithoutResponse;
    final useWithoutResponse = withoutResponse
        ? canWriteNoResp
        : (!canWrite && canWriteNoResp);

    if (!canWrite && !canWriteNoResp) {
      throw StateError('Characteristic ${c.uuid.str} is not writable');
    }

    final job = _WriteJob(
      bytes: bytes,
      withoutResponse: useWithoutResponse,
      characteristic: c,
      role: target == BleWriteTarget.c1 ? 'C1' : 'C3',
      completer: Completer<void>(),
    );
    _writeQueue.addLast(job);
    _pumpWriteQueue();
    return job.completer.future;
  }

  Future<void> _pumpWriteQueue() async {
    if (_writePumpRunning) return;
    _writePumpRunning = true;
    try {
      while (_writeQueue.isNotEmpty) {
        final job = _writeQueue.removeFirst();
        try {
          await _performWrite(job);
          if (!job.completer.isCompleted) job.completer.complete();
        } catch (e, st) {
          if (!job.completer.isCompleted) {
            job.completer.completeError(e, st);
          }
        }
      }
    } finally {
      _writePumpRunning = false;
      if (_writeQueue.isNotEmpty) {
        unawaited(_pumpWriteQueue());
      }
    }
  }

  Future<void> _performWrite(_WriteJob job) async {
    final c = job.characteristic;
    if (!_connected) throw StateError('Not connected');

    _clearFlag(BleLinkFlags.dataWritten);
    _setFlag(BleLinkFlags.busy);

    final maxAttempts = config.writeRetryAttempts.clamp(1, 5);
    Object? lastError;
    final isFirstAppWrite = !_firstAuthWriteLogged;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (isFirstAppWrite && attempt == 1) {
        _firstAuthWriteLogged = true;
        pipelineTimer?.mark('FIRST_AUTH_WRITE_START role=${job.role}');
        BleLog.d(
          'FIRST_AUTH_WRITE at t=${pipelineTimer?.elapsedMs ?? -1}ms '
          'after CONNECT (must be << 5000ms firmware idle)',
        );
      }
      _logWriteDiagnostics(
        c: c,
        bytes: job.bytes,
        role: job.role,
        withoutResponse: job.withoutResponse,
      );
      BleLog.d(
        'WRITE attempt $attempt/$maxAttempts role=${job.role} '
        'len=${job.bytes.length} t=${pipelineTimer?.elapsedMs}ms',
      );

      // Java sleep(100) is between successive writes — skip before first AUTH.
      if (!isFirstAppWrite && config.writeSpacing > Duration.zero) {
        await Future<void>.delayed(config.writeSpacing);
      } else if (isFirstAppWrite) {
        BleLog.d('WRITE skip writeSpacing on first AUTH (idle-timeout safe)');
      }

      try {
        await c
            .write(
              job.bytes,
              withoutResponse: job.withoutResponse,
              timeout: config.writeTimeout.inSeconds.clamp(1, 60),
            )
            .timeout(
              config.writeTimeout,
              onTimeout: () => throw TimeoutException(
                'Write timed out after ${config.writeTimeout}',
              ),
            );

        txPacketCount += 1;
        _setFlag(BleLinkFlags.dataWritten);
        _clearFlag(BleLinkFlags.busy);
        if (isFirstAppWrite && attempt == 1) {
          pipelineTimer?.mark('FIRST_AUTH_WRITE_SUCCESS');
          pipelineTimer?.report(
            headline:
                'First AUTH write completed — compare vs ~5000ms idle budget',
          );
        }
        BleLog.d(
          'WRITE SUCCESS role=${job.role} uuid=${c.uuid.str} '
          'len=${job.bytes.length} t=${pipelineTimer?.elapsedMs}ms',
        );
        return;
      } catch (e) {
        lastError = e;
        final is133 = _isGatt133(e);
        BleLog.e(
          'WRITE FAILED role=${job.role} attempt=$attempt/$maxAttempts '
          'gatt133=$is133 t=${pipelineTimer?.elapsedMs}ms',
          e,
        );
        if (isFirstAppWrite) {
          pipelineTimer?.mark('FIRST_AUTH_WRITE_FAILED attempt=$attempt');
          pipelineTimer?.report(
            headline: 'First AUTH write FAILED — timing dump',
          );
        }
        if (is133 && attempt < maxAttempts) {
          final backoff = Duration(milliseconds: 300 * attempt);
          BleLog.d('GATT 133 on write — retry after $backoff');
          await Future<void>.delayed(backoff);
          continue;
        }
        break;
      }
    }

    _clearFlag(BleLinkFlags.busy);
    _fail('Write Fail [${job.role}]: $lastError');
    throw StateError(
      'writeCharacteristic failed [${job.role}] after $maxAttempts '
      'attempts: $lastError',
    );
  }

  String _hexPreview(Uint8List bytes, {int max = 24}) {
    final take = bytes.length < max ? bytes.length : max;
    final hex = bytes
        .sublist(0, take)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    return bytes.length > max ? '$hex…' : hex;
  }

  @override
  Future<Uint8List?> read() async {
    final c = _notifyChar ?? _writeChar;
    if (c == null) return null;
    if (!c.properties.read) return null;
    final value = await c.read();
    return Uint8List.fromList(value);
  }

  @override
  Future<int?> readRssi() async {
    final d = _device;
    if (d == null || !_connected) return null;
    final rssi = await d.readRssi();
    _rssiController.add(rssi);
    _setFlag(BleLinkFlags.rssiReceived);
    BleLog.rssi(rssi);
    return rssi;
  }

  @override
  Future<void> dispose() async {
    _stopRssiPolling();
    await stopScan();
    await disconnect();
    await _adapterSub?.cancel();
    await _connSub?.cancel();
    await _adapterController.close();
    await _scanController.close();
    await _connectionController.close();
    await _notificationController.close();
    await _rssiController.close();
    await _linkStateController.close();
  }
}

class _WriteJob {
  _WriteJob({
    required this.bytes,
    required this.withoutResponse,
    required this.characteristic,
    required this.role,
    required this.completer,
  });

  final Uint8List bytes;
  final bool withoutResponse;
  final BluetoothCharacteristic characteristic;
  final String role;
  final Completer<void> completer;
}
