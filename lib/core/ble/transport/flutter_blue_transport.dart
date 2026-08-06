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
  });

  final String uuid;
  final String properties;
  final bool isCommand;
  final bool isStatus;
}

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
      permissions.add(Permission.locationWhenInUse);
    }

    final statuses = await permissions.request();
    final permanentlyDenied = statuses.values.any((s) => s.isPermanentlyDenied);
    if (permanentlyDenied) {
      await openAppSettings();
      throw StateError(
        'Bluetooth permissions permanently denied — enable them in Settings',
      );
    }
    final denied = statuses.values.any(
      (s) => s.isDenied || s.isRestricted,
    );
    if (denied) {
      throw StateError(
        'Bluetooth permissions not granted '
        '(need BLUETOOTH_SCAN, BLUETOOTH_CONNECT'
        '${Platform.isAndroid ? ', LOCATION' : ''})',
      );
    }
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

  @override
  Future<List<BleDevice>> startScan({
    required Duration timeout,
    String? namePrefix,
  }) async {
    await ensurePermissions();
    await _checkBtEnabled();
    BleLog.d('Scan start timeout=${timeout.inSeconds}s '
        'service=${config.serviceUuid.str}');

    _seen.clear();
    await _scanSub?.cancel();
    final prefix = namePrefix ?? config.deviceNamePrefix;

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.advertisementData.advName.isNotEmpty
            ? r.advertisementData.advName
            : r.device.platformName;

        // Defense-in-depth: keep only our Service UUID (OS also filters via
        // withServices). Name prefix is optional — empty = UUID-only.
        final advertised = r.advertisementData.serviceUuids
            .any((u) => _guidEquals(u, config.serviceUuid));
        // withServices may deliver a hit before serviceUuids is populated on
        // some stacks — accept those; drop clear non-matches when listed.
        if (r.advertisementData.serviceUuids.isNotEmpty && !advertised) {
          continue;
        }
        if (prefix.isNotEmpty &&
            name.isNotEmpty &&
            !name.toUpperCase().startsWith(prefix.toUpperCase()) &&
            !advertised) {
          continue;
        }

        final device = BleDevice(
          id: r.device.remoteId.str,
          name: name.isEmpty ? 'CC2340 (${r.device.remoteId.str})' : name,
          rssi: r.rssi,
          advertisementName: r.advertisementData.advName,
          isConnectable: r.advertisementData.connectable,
        );
        _seen[device.id] = device;
      }
      _scanController.add(_seen.values.toList());
    });

    // Manifest uses BLUETOOTH_SCAN neverForLocation — do not request fine
    // location for scanning (Android 12+ Service UUID filter is enough).
    await FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: [config.serviceUuid],
      androidUsesFineLocation: false,
    );
    await Future<void>.delayed(timeout);
    await stopScan();
    BleLog.d('Scan done devices=${_seen.length}');
    return _seen.values.toList();
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
        _setFlag(BleLinkFlags.connected);
        _clearFlag(BleLinkFlags.busy);
        _connectionController.add(true);
        BleLog.d('Connected attempt=$attempt');

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

        _startRssiPolling();
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
    discoveredServices = const [];
    lastMtu = null;
    connectedAt = null;
    _connected = false;
    _setLink(const BleLinkState());
    _connectionController.add(false);
  }

  @override
  Future<int> requestMtu(int mtu) async {
    final d = _device;
    if (d == null) return 23;
    // Java requests 512; accept whatever the stack negotiates.
    final requested = mtu < 23 ? 23 : mtu;
    BleLog.d('Request MTU $requested');
    try {
      final negotiated = await d.requestMtu(requested);
      lastMtu = negotiated;
      _setFlag(BleLinkFlags.mtuSet);
      BleLog.d('MTU negotiated=$negotiated');
      return negotiated;
    } catch (e) {
      BleLog.d('MTU request failed (using fallback): $e');
      lastMtu ??= 23;
      // Still mark set so pipeline can continue on stacks that manage MTU.
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
    final snapshot = <GattServiceInfo>[];
    var serviceFound = false;

    for (final s in services) {
      final isTarget = _guidEquals(s.uuid, config.serviceUuid);
      if (isTarget) serviceFound = true;
      final chars = <GattCharacteristicInfo>[];
      for (final c in s.characteristics) {
        final isCommand = _guidEquals(c.uuid, config.writeCharacteristicUuid);
        final isStatus = _guidEquals(c.uuid, config.notifyCharacteristicUuid);
        if (isCommand) write = c;
        if (isStatus) notify = c;
        chars.add(
          GattCharacteristicInfo(
            uuid: c.uuid.str,
            properties: _propsLabel(c.properties),
            isCommand: isCommand,
            isStatus: isStatus,
          ),
        );
        if (isTarget) {
          BleLog.d('Characteristic ${c.uuid.str} ${_propsLabel(c.properties)}');
        }
      }
      snapshot.add(
        GattServiceInfo(uuid: s.uuid.str, characteristics: chars),
      );
    }
    discoveredServices = snapshot;

    if (!serviceFound) {
      _fail('BT No Services — missing ${config.serviceUuid.str}');
      throw StateError(
        'BT No Services — required service ${config.serviceUuid.str} not found',
      );
    }
    if (write == null || notify == null) {
      _fail('BT Bad Service — Char1=${write != null} Char4=${notify != null}');
      throw StateError(
        'BT Bad Service — '
        'command(Char1)=${write != null} status(Char4)=${notify != null}',
      );
    }
    _writeChar = write;
    _notifyChar = notify;
    _setFlag(BleLinkFlags.servicesDiscovered);
    BleLog.d('Services discovered Char1=yes Char4=yes');
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
    if (c == null) throw StateError('Status characteristic (Char 4) missing');
    if (!c.properties.notify && !c.properties.indicate) {
      throw StateError(
        'Status characteristic does not support NOTIFY/INDICATE',
      );
    }

    BleLog.d('Enable notifications on ${c.uuid.str}');
    await c.setNotifyValue(true);

    // Java writes CCCD 0x2902 explicitly. FBP setNotifyValue does this;
    // verify the descriptor exists for diagnostics.
    try {
      final descriptors = c.descriptors;
      final cccd = descriptors.where((d) => _guidEquals(d.uuid, _cccdUuid));
      if (cccd.isEmpty) {
        BleLog.d('CCCD 0x2902 not listed — relying on setNotifyValue');
      } else {
        BleLog.d('CCCD 0x2902 present');
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
    BleLog.d('BT Ready (notifications on)');
  }

  @override
  Future<void> write(Uint8List bytes, {bool withoutResponse = false}) async {
    final c = _writeChar;
    if (c == null) throw StateError('Command characteristic (Char 1) missing');
    if (!_connected) throw StateError('Not connected');

    final maxLen = config.commandCharacteristicMaxBytes;
    // Prefer ATT MTU-3 when negotiated higher than declared char length.
    final attPayload = (lastMtu != null && lastMtu! > 3) ? lastMtu! - 3 : maxLen;
    final hardMax = attPayload < maxLen ? attPayload : maxLen;
    if (bytes.length > hardMax) {
      throw StateError(
        'Command packet ${bytes.length} bytes exceeds write max ($hardMax)',
      );
    }

    final canWrite = c.properties.write;
    final canWriteNoResp = c.properties.writeWithoutResponse;
    final useWithoutResponse = withoutResponse
        ? canWriteNoResp
        : (!canWrite && canWriteNoResp);

    if (!canWrite && !canWriteNoResp) {
      throw StateError('Command characteristic is not writable');
    }

    // Serialize writes — Java waits for S_DATA_WRITTEN before next setData.
    final job = _WriteJob(
      bytes: bytes,
      withoutResponse: useWithoutResponse,
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
        // A write was enqueued while we were finishing — continue.
        unawaited(_pumpWriteQueue());
      }
    }
  }

  Future<void> _performWrite(_WriteJob job) async {
    final c = _writeChar;
    if (c == null) throw StateError('Command characteristic (Char 1) missing');
    if (!_connected) throw StateError('Not connected');

    _clearFlag(BleLinkFlags.dataWritten);
    _setFlag(BleLinkFlags.busy);
    BleLog.tx('${job.bytes.length}B withoutResponse=${job.withoutResponse} '
        '${_hexPreview(job.bytes)}');

    // Small inter-write delay like Java sleep(100) before setValue.
    await Future<void>.delayed(config.writeSpacing);

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
    required this.completer,
  });

  final Uint8List bytes;
  final bool withoutResponse;
  final Completer<void> completer;
}
