import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:virtual_mcu/virtual_mcu.dart';

import '../../../core/ble/ble.dart';
import '../models/dashboard_models.dart';

/// Dashboard state — pure view model over the shared Virtual MCU.
class DeveloperDashboardState {
  const DeveloperDashboardState({
    this.mcuAvailable = false,
    this.status,
    this.boxes = const [],
    this.matrixRows = 4,
    this.matrixCols = 4,
    this.packets = const [],
    this.events = const [],
    this.tableRows = const [],
    this.stats = const DashboardStats(),
    this.selectedBoxId,
    this.packetFilter,
    this.packetPaused = false,
    this.activeNode = ArchitectureNode.flutterApp,
    this.demoStatus,
    this.lastAck,
  });

  final bool mcuAvailable;
  final McuStatusView? status;
  final List<BoxRuntime> boxes;
  final int matrixRows;
  final int matrixCols;
  final List<PacketMonitorEntry> packets;
  final List<RuntimeLogEntry> events;
  final List<McuTableRow> tableRows;
  final DashboardStats stats;
  final String? selectedBoxId;
  final String? packetFilter;
  final bool packetPaused;
  final ArchitectureNode activeNode;
  final String? demoStatus;
  final String? lastAck;

  DeveloperDashboardState copyWith({
    bool? mcuAvailable,
    McuStatusView? status,
    List<BoxRuntime>? boxes,
    int? matrixRows,
    int? matrixCols,
    List<PacketMonitorEntry>? packets,
    List<RuntimeLogEntry>? events,
    List<McuTableRow>? tableRows,
    DashboardStats? stats,
    String? selectedBoxId,
    String? packetFilter,
    bool? packetPaused,
    ArchitectureNode? activeNode,
    String? demoStatus,
    String? lastAck,
    bool clearSelectedBox = false,
    bool clearDemoStatus = false,
  }) {
    return DeveloperDashboardState(
      mcuAvailable: mcuAvailable ?? this.mcuAvailable,
      status: status ?? this.status,
      boxes: boxes ?? this.boxes,
      matrixRows: matrixRows ?? this.matrixRows,
      matrixCols: matrixCols ?? this.matrixCols,
      packets: packets ?? this.packets,
      events: events ?? this.events,
      tableRows: tableRows ?? this.tableRows,
      stats: stats ?? this.stats,
      selectedBoxId:
          clearSelectedBox ? null : (selectedBoxId ?? this.selectedBoxId),
      packetFilter: packetFilter ?? this.packetFilter,
      packetPaused: packetPaused ?? this.packetPaused,
      activeNode: activeNode ?? this.activeNode,
      demoStatus: clearDemoStatus ? null : (demoStatus ?? this.demoStatus),
      lastAck: lastAck ?? this.lastAck,
    );
  }
}

/// Orchestrates visualization + simulation triggers against existing MCUCore.
class DeveloperDashboardController extends Notifier<DeveloperDashboardState> {
  StreamSubscription<Packet>? _packetSub;
  StreamSubscription<Uint8List>? _outboundSub;
  StreamSubscription<LockerState>? _lockerStateSub;
  Map<String, String> _lastVars = {};
  DateTime? _lastSendAt;
  String? _selectedBox;

  LockerService get _locker => ref.read(lockerServiceProvider);
  MCUCore? get _mcu => _locker.virtualMcu;

  @override
  DeveloperDashboardState build() {
    ref.onDispose(() {
      _packetSub?.cancel();
      _outboundSub?.cancel();
      _lockerStateSub?.cancel();
    });

    ref.listen(bleConfigProvider, (prev, next) {
      state = const DeveloperDashboardState();
      Future.microtask(_attach);
    });

    // Defer attach so provider finishes build.
    Future.microtask(_attach);
    return const DeveloperDashboardState();
  }

  void _attach() {
    final mcu = _mcu;
    if (mcu == null) {
      state = state.copyWith(mcuAvailable: false);
      return;
    }

    _packetSub?.cancel();
    _packetSub = _locker.packetStream.cast<Packet>().listen((packet) {
      _onAppPacket(packet);
    });

    _outboundSub?.cancel();
    _outboundSub = mcu.outboundNotifications.listen((_) {
      _refreshFromMcu(reason: 'mcu_outbound');
      _setActive(ArchitectureNode.mcuCore);
    });

    _lockerStateSub?.cancel();
    _lockerStateSub = _locker.stateStream.listen((_) {
      _refreshFromMcu(reason: 'locker_state');
    });

    _selectedBox = mcu.matrix.boxes.isNotEmpty ? mcu.matrix.boxes.first.boxId : null;
    _refreshFromMcu(reason: 'attach');
  }

  void _setActive(ArchitectureNode node) {
    state = state.copyWith(activeNode: node);
  }

  void _onAppPacket(Packet packet) {
    if (!state.packetPaused) {
      final entry = PacketMonitorEntry(
        timestamp: DateTime.now(),
        direction: PacketDirection.mcuToApp,
        sequenceNumber: packet.header.sequenceNumber,
        packetType: packet.packetType.wireName,
        payload: jsonEncode(packet.payload.asJsonMap() ?? {}),
        ack: packet.packetType.wireName.contains('ACK') ? 'ACK' : '-',
        result: packet.packetType == BlePacketType.error ? 'ERROR' : 'OK',
      );
      _pushPacket(entry);
      if (entry.ack == 'ACK') {
        state = state.copyWith(
          lastAck: entry.packetType,
          stats: state.stats.copyWith(
            packetsReceived: state.stats.packetsReceived + 1,
            ackCount: state.stats.ackCount + 1,
          ),
        );
      } else if (packet.packetType == BlePacketType.error) {
        state = state.copyWith(
          stats: state.stats.copyWith(
            packetsReceived: state.stats.packetsReceived + 1,
            errorCount: state.stats.errorCount + 1,
          ),
        );
      } else {
        state = state.copyWith(
          stats: state.stats.copyWith(
            packetsReceived: state.stats.packetsReceived + 1,
          ),
        );
      }
      if (_lastSendAt != null) {
        final ms = DateTime.now().difference(_lastSendAt!).inMilliseconds;
        state = state.copyWith(
          stats: state.stats.copyWith(
            totalResponseMs: state.stats.totalResponseMs + ms,
            responseSamples: state.stats.responseSamples + 1,
          ),
        );
        _lastSendAt = null;
      }
    }
    _setActive(ArchitectureNode.bleProtocol);
    _refreshFromMcu(reason: 'packet_${packet.packetType.wireName}');
  }

  void _pushPacket(PacketMonitorEntry entry) {
    final next = [...state.packets, entry];
    final trimmed = next.length > 300 ? next.sublist(next.length - 300) : next;
    state = state.copyWith(packets: trimmed);
  }

  void _recordTx({
    required String type,
    required int seq,
    required String payload,
    required String result,
  }) {
    if (state.packetPaused) return;
    _pushPacket(
      PacketMonitorEntry(
        timestamp: DateTime.now(),
        direction: PacketDirection.appToMcu,
        sequenceNumber: seq,
        packetType: type,
        payload: payload,
        ack: '-',
        result: result,
      ),
    );
    state = state.copyWith(
      stats: state.stats.copyWith(packetsSent: state.stats.packetsSent + 1),
    );
    _lastSendAt = DateTime.now();
  }

  void _refreshFromMcu({required String reason}) {
    final mcu = _mcu;
    if (mcu == null) {
      state = state.copyWith(mcuAvailable: false);
      return;
    }

    final vars = <String, String>{
      'authenticated': '${mcu.state.authenticated}',
      'bleConnected': '${mcu.state.bleConnected}',
      'packetCounter': '${mcu.state.packetCounter}',
      'heartbeatCounter': '${mcu.state.heartbeatCounter}',
      'battery': '${mcu.state.batteryLevel}',
      'rssi': '${mcu.state.rssi}',
      'lastPacket': mcu.state.lastPacket ?? '',
      'lastError': mcu.state.lastError ?? '',
      for (final b in mcu.matrix.boxes) 'door:${b.boxId}': b.doorState.name,
      for (final b in mcu.matrix.boxes) 'lock:${b.boxId}': b.lockState.name,
      for (final b in mcu.matrix.boxes) 'busy:${b.boxId}': '${b.busy}',
    };

    final changes = <McuTableRow>[];
    vars.forEach((key, value) {
      final prev = _lastVars[key];
      if (prev != null && prev != value) {
        changes.add(
          McuTableRow(
            timestamp: DateTime.now(),
            variable: key,
            previousValue: prev,
            currentValue: value,
            reason: reason,
          ),
        );
      }
    });
    _lastVars = vars;

    final table = [...changes.reversed, ...state.tableRows];
    final trimmedTable =
        table.length > 400 ? table.sublist(0, 400) : table;

    state = state.copyWith(
      mcuAvailable: true,
      status: McuStatusView.fromMcu(mcu, lastAck: state.lastAck),
      boxes: mcu.matrix.boxes.map((b) => b.copy()).toList(),
      matrixRows: mcu.config.rows,
      matrixCols: mcu.config.cols,
      events: List<RuntimeLogEntry>.from(mcu.logger.entries.reversed),
      tableRows: trimmedTable,
      selectedBoxId: _selectedBox,
    );
  }

  void selectBox(String boxId) {
    _selectedBox = boxId;
    state = state.copyWith(selectedBoxId: boxId);
  }

  void setPacketFilter(String? type) {
    state = state.copyWith(packetFilter: type);
  }

  void togglePacketPause() {
    state = state.copyWith(packetPaused: !state.packetPaused);
  }

  void clearPackets() {
    state = state.copyWith(packets: const []);
  }

  String exportPacketsJson() {
    final data = state.packets
        .map(
          (p) => {
            'timestamp': p.timestamp.toIso8601String(),
            'direction': p.direction.name,
            'sequence': p.sequenceNumber,
            'type': p.packetType,
            'payload': p.payload,
            'ack': p.ack,
            'result': p.result,
          },
        )
        .toList();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  BoxRuntime? selectedBox() {
    final id = state.selectedBoxId;
    if (id == null) return null;
    for (final b in state.boxes) {
      if (b.boxId == id) return b;
    }
    return null;
  }

  // --- Simulation panel (calls existing MCU / LockerService APIs) ---

  Future<void> simulateAuthenticate() async {
    final mcu = _mcu;
    if (mcu == null) return;
    _setActive(ArchitectureNode.lockerService);
    await _ensureConnected();
    final boxId = _selectedBox ?? 'BOX-03';
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600;
    final token = 'CE1.ORD-DEV.LCK-A1.$boxId.$exp.devtoken';
    _recordTx(type: 'AUTH', seq: 0, payload: token, result: 'pending');
    final result = await _locker.authenticateCollection(
      orderId: 'ORD-DEV',
      lockerId: mcu.state.lockerId,
      boxId: boxId,
      collectionToken: token,
    );
    state = state.copyWith(
      stats: state.stats.copyWith(authCount: state.stats.authCount + 1),
      demoStatus: result.success ? 'AUTH ok' : 'AUTH failed: ${result.message}',
    );
    _refreshFromMcu(reason: 'simulate_authenticate');
  }

  Future<void> simulateDisconnect() async {
    await _locker.disconnectSafely();
    state = state.copyWith(
      stats: state.stats.copyWith(
        reconnectCount: state.stats.reconnectCount,
      ),
      demoStatus: 'Disconnected',
    );
    _refreshFromMcu(reason: 'disconnect');
  }

  Future<void> simulateReconnect() async {
    final devices = await _locker.scanForLockers();
    if (devices.isEmpty) return;
    await _locker.connect(devices.first, lockerId: _mcu?.state.lockerId);
    state = state.copyWith(
      stats: state.stats.copyWith(
        reconnectCount: state.stats.reconnectCount + 1,
      ),
      demoStatus: 'Reconnected',
    );
    _refreshFromMcu(reason: 'reconnect');
  }

  Future<void> simulateHeartbeat() async {
    final mcu = _mcu;
    if (mcu == null) return;
    _setActive(ArchitectureNode.mcuCore);
    // Trigger status as stand-in; heartbeats also arrive via outbound stream.
    await _locker.requestLockerStatus(
      lockerId: mcu.state.lockerId,
      boxId: _selectedBox ?? '',
    );
    _refreshFromMcu(reason: 'heartbeat_status');
  }

  Future<void> simulateOpenBox() async {
    final mcu = _mcu;
    if (mcu == null) return;
    final boxId = _selectedBox ?? 'BOX-03';
    await _ensureAuthenticated(boxId);
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600;
    final token = 'CE1.ORD-DEV.LCK-A1.$boxId.$exp.devtoken';
    _recordTx(type: 'OPEN_BOX', seq: 0, payload: boxId, result: 'pending');
    final result = await _locker.openBox(
      orderId: 'ORD-DEV',
      lockerId: mcu.state.lockerId,
      boxId: boxId,
      collectionToken: token,
    );
    if (result.success) {
      state = state.copyWith(
        stats: state.stats.copyWith(doorOpens: state.stats.doorOpens + 1),
        demoStatus: 'Opened $boxId',
      );
    } else {
      state = state.copyWith(demoStatus: 'Open failed: ${result.message}');
    }
    _refreshFromMcu(reason: 'open_box');
  }

  Future<void> simulateCloseDoor() async {
    final mcu = _mcu;
    final boxId = _selectedBox;
    if (mcu == null || boxId == null) return;
    final box = mcu.matrix.find(boxId);
    if (box == null) return;
    await mcu.doors.close(box);
    state = state.copyWith(
      stats: state.stats.copyWith(doorCloses: state.stats.doorCloses + 1),
      demoStatus: 'Closed $boxId',
    );
    mcu.logger.log(
      event: 'DOOR_CLOSE',
      box: boxId,
      door: box.doorState.name,
      result: 'ok',
    );
    _refreshFromMcu(reason: 'close_door');
  }

  void simulateResetMcu() {
    _mcu?.resetMcu();
    state = state.copyWith(demoStatus: 'MCU reset');
    _refreshFromMcu(reason: 'reset_mcu');
  }

  void simulateResetLocker() {
    _mcu?.resetLocker();
    state = state.copyWith(demoStatus: 'Locker reset');
    _refreshFromMcu(reason: 'reset_locker');
  }

  void simulateReserveBox() {
    final id = _selectedBox;
    if (id == null) return;
    _mcu?.reserveBox(id);
    state = state.copyWith(demoStatus: 'Reserved $id');
    _refreshFromMcu(reason: 'reserve');
  }

  void simulateReleaseBox() {
    final id = _selectedBox;
    if (id == null) return;
    _mcu?.releaseBox(id);
    state = state.copyWith(demoStatus: 'Released $id');
    _refreshFromMcu(reason: 'release');
  }

  void simulateLowBattery() {
    final mcu = _mcu;
    if (mcu == null) return;
    mcu.state.batteryLevel = 8;
    mcu.logger.log(event: 'SIM_LOW_BATTERY', result: '8%');
    state = state.copyWith(demoStatus: 'Battery → 8%');
    _refreshFromMcu(reason: 'low_battery');
  }

  void simulateLowRssi() {
    final mcu = _mcu;
    if (mcu == null) return;
    mcu.state.rssi = -92;
    mcu.logger.log(event: 'SIM_LOW_RSSI', result: '-92');
    state = state.copyWith(demoStatus: 'RSSI → -92');
    _refreshFromMcu(reason: 'low_rssi');
  }

  void simulateDoorJam() {
    final mcu = _mcu;
    final id = _selectedBox;
    if (mcu == null || id == null) return;
    final box = mcu.matrix.find(id);
    if (box == null) return;
    box.doorState = DoorState.jammed;
    box.motorState = MotorState.fault;
    box.sensorState = SensorState.fault;
    box.lastError = 'DOOR_JAM';
    mcu.state.lastError = 'DOOR_JAM';
    mcu.logger.log(event: 'DOOR_JAM', box: id, result: 'fault');
    state = state.copyWith(demoStatus: 'Door jam on $id');
    _refreshFromMcu(reason: 'door_jam');
  }

  void simulateMotorFailure() {
    final mcu = _mcu;
    final id = _selectedBox;
    if (mcu == null || id == null) return;
    final box = mcu.matrix.find(id);
    if (box == null) return;
    box.motorState = MotorState.fault;
    box.lastError = 'MOTOR_FAILURE';
    mcu.logger.log(event: 'MOTOR_FAILURE', box: id, result: 'fault');
    state = state.copyWith(demoStatus: 'Motor failure on $id');
    _refreshFromMcu(reason: 'motor_failure');
  }

  Future<void> simulateCrcFailure() async {
    final mcu = _mcu;
    if (mcu == null) return;
    // Corrupt frame into MCU — uses existing decode CRC check.
    final bad = Uint8List.fromList([1, 1, 0, 1, 0, 0, 0, 1, 0, 0xFF, 0xFF]);
    _recordTx(type: 'CORRUPT', seq: 0, payload: 'crc', result: 'inject');
    final res = await mcu.handleWrite(bad);
    state = state.copyWith(
      demoStatus: res == null ? 'No response' : 'CRC path exercised',
      stats: state.stats.copyWith(errorCount: state.stats.errorCount + 1),
    );
    _refreshFromMcu(reason: 'crc_failure');
  }

  Future<void> simulateTimeout() async {
    // Demo MCU with forceBleTimeout — does not alter shared config permanently.
    final demo = MCUCore(
      config: const SimulationConfig(forceBleTimeout: true),
    );
    demo.connectBle();
    final res = await demo.handleWrite(
      const FrameCodec().encode(type: McuPacketType.ping, sequenceNumber: 1),
    );
    await demo.dispose();
    state = state.copyWith(
      demoStatus: res == null ? 'Timeout demo: no response' : 'Unexpected',
    );
    _recordTx(type: 'PING', seq: 1, payload: '{}', result: 'timeout_demo');
  }

  Future<void> simulatePacketLoss() async {
    final demo = MCUCore(
      config: const SimulationConfig(packetLossRate: 1.0),
    );
    demo.connectBle();
    final res = await demo.handleWrite(
      const FrameCodec().encode(type: McuPacketType.ping, sequenceNumber: 1),
    );
    await demo.dispose();
    state = state.copyWith(
      demoStatus: res == null ? 'Packet loss demo: dropped' : 'Unexpected',
    );
  }

  void simulateBusyLocker() {
    final mcu = _mcu;
    final id = _selectedBox;
    if (mcu == null || id == null) return;
    final box = mcu.matrix.find(id);
    if (box == null) return;
    box.busy = true;
    mcu.logger.log(event: 'LOCKER_BUSY', box: id, result: 'busy');
    state = state.copyWith(demoStatus: '$id busy');
    _refreshFromMcu(reason: 'busy');
  }

  Future<void> simulateInvalidToken() async {
    await _ensureConnected();
    try {
      await _locker.authenticateCollection(
        orderId: 'ORD-BAD',
        lockerId: _mcu?.state.lockerId ?? 'LCK-A1',
        boxId: _selectedBox ?? 'BOX-03',
        collectionToken: 'not-a-token',
      );
      state = state.copyWith(demoStatus: 'Unexpected ok');
    } catch (_) {
      state = state.copyWith(
        demoStatus: 'Invalid token rejected',
        stats: state.stats.copyWith(errorCount: state.stats.errorCount + 1),
      );
    }
    _refreshFromMcu(reason: 'invalid_token');
  }

  Future<void> simulateExpiredToken() async {
    await _ensureConnected();
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 120;
    final boxId = _selectedBox ?? 'BOX-03';
    final token = 'CE1.ORD-OLD.LCK-A1.$boxId.$exp.old';
    try {
      await _locker.authenticateCollection(
        orderId: 'ORD-OLD',
        lockerId: _mcu?.state.lockerId ?? 'LCK-A1',
        boxId: boxId,
        collectionToken: token,
      );
      state = state.copyWith(demoStatus: 'Unexpected ok');
    } catch (e) {
      state = state.copyWith(demoStatus: 'Expired token rejected');
    }
    _refreshFromMcu(reason: 'expired_token');
  }

  Future<void> simulateWrongBox() async {
    final mcu = _mcu;
    if (mcu == null) return;
    await _ensureConnected();
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600;
    final token = 'CE1.ORD-DEV.LCK-A1.BOX-01.$exp.devtoken';
    final result = await _locker.authenticateCollection(
      orderId: 'ORD-DEV',
      lockerId: mcu.state.lockerId,
      boxId: 'BOX-99',
      collectionToken: token,
    );
    state = state.copyWith(
      demoStatus: result.success ? 'Unexpected' : 'Wrong box rejected',
    );
    _refreshFromMcu(reason: 'wrong_box');
  }

  void simulateDoorAlreadyOpen() {
    final mcu = _mcu;
    final id = _selectedBox;
    if (mcu == null || id == null) return;
    final box = mcu.matrix.find(id);
    if (box == null) return;
    box.doorState = DoorState.open;
    box.lockState = LockState.unlocked;
    mcu.logger.log(event: 'DOOR_ALREADY_OPEN', box: id, result: 'open');
    state = state.copyWith(demoStatus: '$id marked open');
    _refreshFromMcu(reason: 'door_already_open');
  }

  // --- Test mode demos ---

  Future<void> runAuthDemo() async {
    state = state.copyWith(demoStatus: 'Running auth demo…');
    await simulateReconnect();
    await simulateAuthenticate();
  }

  Future<void> runPurchaseDemo() async {
    state = state.copyWith(demoStatus: 'Running purchase/open demo…');
    await simulateReconnect();
    await simulateAuthenticate();
    await simulateOpenBox();
  }

  Future<void> runOpenBoxDemo() async {
    await runPurchaseDemo();
  }

  Future<void> runTimeoutDemo() => simulateTimeout();
  Future<void> runPacketLossDemo() => simulatePacketLoss();
  Future<void> runDoorJamDemo() async {
    await simulateReconnect();
    simulateDoorJam();
    state = state.copyWith(demoStatus: 'Door jam demo applied');
  }

  Future<void> _ensureConnected() async {
    if (_locker.state == LockerState.disconnected ||
        _locker.state == LockerState.failure ||
        !_locker.transport.isConnected) {
      await simulateReconnect();
    }
  }

  Future<void> _ensureAuthenticated(String boxId) async {
    await _ensureConnected();
    if (_mcu?.state.authenticated != true) {
      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600;
      final token = 'CE1.ORD-DEV.LCK-A1.$boxId.$exp.devtoken';
      await _locker.authenticateCollection(
        orderId: 'ORD-DEV',
        lockerId: _mcu!.state.lockerId,
        boxId: boxId,
        collectionToken: token,
      );
      state = state.copyWith(
        stats: state.stats.copyWith(authCount: state.stats.authCount + 1),
      );
    }
  }
}

final developerDashboardProvider =
    NotifierProvider<DeveloperDashboardController, DeveloperDashboardState>(
  DeveloperDashboardController.new,
);
