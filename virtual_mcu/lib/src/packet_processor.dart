import 'dart:math';
import 'dart:typed_data';

import 'authentication_engine.dart';
import 'box_runtime.dart';
import 'door_controller.dart';
import 'error_manager.dart';
import 'locker_matrix.dart';
import 'motor_simulator.dart';
import 'runtime_logger.dart';
import 'runtime_state.dart';
import 'sensor_simulator.dart';
import 'sequence_manager.dart';
import 'simulation_config.dart';
import 'wire/frame_codec.dart';
import 'wire/packet_types.dart';

/// Decodes inbound frames and builds firmware-style responses.
class PacketProcessor {
  PacketProcessor({
    required this.config,
    required this.matrix,
    required this.state,
    required this.logger,
    required this.sequences,
    required this.auth,
    required this.doors,
    required this.motors,
    required this.sensors,
    required this.errors,
    FrameCodec? codec,
    Random? random,
  })  : codec = codec ?? const FrameCodec(),
        _random = random ?? Random();

  final SimulationConfig config;
  final LockerMatrix matrix;
  final McuRuntimeState state;
  final RuntimeLogger logger;
  final SequenceManager sequences;
  final AuthenticationEngine auth;
  final DoorController doors;
  final MotorSimulator motors;
  final SensorSimulator sensors;
  final ErrorManager errors;
  final FrameCodec codec;
  final Random _random;

  /// Process one inbound GATT write. Null = no notification (drop / disconnect).
  Future<Uint8List?> process(Uint8List raw) async {
    state.packetCounter += 1;
    state.uptimeSeconds =
        DateTime.now().difference(state.bootedAt).inSeconds;

    if (_random.nextDouble() < config.packetLossRate) {
      logger.log(event: 'PACKET_LOSS', result: 'dropped');
      return null;
    }

    if (config.forceBleTimeout) {
      logger.log(event: 'BLE_TIMEOUT', result: 'no_response');
      return null;
    }

    McuFrame frame;
    try {
      frame = codec.decode(raw);
    } on FormatException catch (e) {
      final code = e.message.contains('CRC')
          ? McuErrorCode.crcFailed
          : McuErrorCode.unknownCommand;
      state.lastError = code.wireName;
      logger.log(event: 'DECODE_FAIL', result: code.wireName, packet: e.message);
      return _errorFrame(
        sequenceNumber: 0,
        code: code,
        message: e.message,
      );
    }

    state.lastPacket = frame.type.label;
    logger.log(
      event: 'RX',
      packet: frame.type.label,
      box: frame.boxId.isEmpty ? null : frame.boxId,
      result: 'ok',
    );

    if (config.forceSequenceError || !sequences.acceptInbound(frame.sequenceNumber)) {
      return _errorFrame(
        sequenceNumber: frame.sequenceNumber,
        orderId: frame.orderId,
        lockerId: frame.lockerId,
        boxId: frame.boxId,
        code: McuErrorCode.sequenceError,
        message: 'duplicate or forced sequence error',
      );
    }

    final preflight = errors.preflightBle();
    if (preflight != null &&
        frame.type != McuPacketType.disconnect &&
        frame.type != McuPacketType.ping) {
      state.lastError = preflight.wireName;
      return _errorFrame(
        sequenceNumber: frame.sequenceNumber,
        orderId: frame.orderId,
        lockerId: frame.lockerId,
        boxId: frame.boxId,
        code: preflight,
        message: 'preflight ${preflight.wireName}',
      );
    }

    switch (frame.type) {
      case McuPacketType.ping:
        return _reply(frame, McuPacketType.pong);
      case McuPacketType.auth:
        return _handleAuth(frame);
      case McuPacketType.openBox:
        return _handleOpen(frame);
      case McuPacketType.status:
        return _handleStatus(frame);
      case McuPacketType.heartbeat:
        return _reply(
          frame,
          McuPacketType.heartbeat,
          payload: codec.jsonPayload({'rssi': state.rssi}),
        );
      case McuPacketType.disconnect:
        state.bleConnected = false;
        state.resetSession();
        logger.log(event: 'DISCONNECT', result: 'ok');
        return null;
      default:
        return _errorFrame(
          sequenceNumber: frame.sequenceNumber,
          code: McuErrorCode.unknownCommand,
          message: 'unexpected ${frame.type.label}',
        );
    }
  }

  Uint8List _reply(
    McuFrame request,
    McuPacketType type, {
    Uint8List? payload,
    String? collectionToken,
  }) {
    final frame = codec.encode(
      type: type,
      sequenceNumber: request.sequenceNumber,
      orderId: request.orderId,
      lockerId: request.lockerId.isEmpty ? matrix.lockerId : request.lockerId,
      boxId: request.boxId,
      collectionToken: collectionToken ?? '',
      payload: payload,
      corruptChecksum: config.forceCrcFailureOnResponse,
    );
    logger.log(
      event: 'TX',
      packet: type.label,
      box: request.boxId.isEmpty ? null : request.boxId,
      result: 'ok',
    );
    return frame;
  }

  Uint8List _errorFrame({
    required int sequenceNumber,
    required McuErrorCode code,
    required String message,
    String orderId = '',
    String lockerId = '',
    String boxId = '',
  }) {
    logger.log(
      event: 'ERROR',
      packet: 'ERROR',
      box: boxId.isEmpty ? null : boxId,
      result: code.wireName,
      extra: {'message': message},
    );
    return codec.encode(
      type: McuPacketType.error,
      sequenceNumber: sequenceNumber,
      orderId: orderId,
      lockerId: lockerId.isEmpty ? matrix.lockerId : lockerId,
      boxId: boxId,
      payload: codec.jsonPayload({
        'code': code.code,
        'name': code.wireName,
        'message': message,
        'retryable': code == McuErrorCode.lockerBusy ||
            code == McuErrorCode.bleTimeout ||
            code == McuErrorCode.crcFailed,
      }),
    );
  }

  Uint8List _handleAuth(McuFrame frame) {
    final result = auth.validate(
      token: frame.collectionToken,
      expectedLockerId: matrix.lockerId,
      expectedBoxId: frame.boxId.isEmpty ? null : frame.boxId,
      forceInvalid: config.forceInvalidToken,
      forceExpired: config.forceExpiredToken,
    );
    if (!result.ok) {
      state.authenticated = false;
      state.lastError = result.error?.wireName;
      // Map expired to INVALID_TOKEN for phone Phase 11 compatibility when needed,
      // but still emit EXPIRED_TOKEN code for richer sim.
      return _errorFrame(
        sequenceNumber: frame.sequenceNumber,
        orderId: frame.orderId,
        lockerId: frame.lockerId,
        boxId: frame.boxId,
        code: result.error ?? McuErrorCode.invalidToken,
        message: result.message ?? 'auth failed',
      );
    }

    state.authenticated = true;
    state.currentOrder = result.orderId ?? frame.orderId;
    state.currentLocker = matrix.lockerId;
    state.currentBox = result.boxId ?? frame.boxId;
    state.currentUser = 'ble-session';
    logger.log(
      event: 'AUTH_OK',
      packet: 'AUTH_ACK',
      box: state.currentBox,
      result: 'accepted',
    );
    return _reply(
      frame,
      McuPacketType.authAck,
      payload: codec.jsonPayload({
        'accepted': true,
        'sessionTtlSeconds': 120,
        'firmwareVersion': state.firmwareVersion,
      }),
    );
  }

  Future<Uint8List?> _handleOpen(McuFrame frame) async {
    if (!state.authenticated) {
      return _errorFrame(
        sequenceNumber: frame.sequenceNumber,
        orderId: frame.orderId,
        lockerId: frame.lockerId,
        boxId: frame.boxId,
        code: McuErrorCode.invalidToken,
        message: 'not authenticated',
      );
    }

    final tokenCheck = auth.validate(
      token: frame.collectionToken,
      expectedLockerId: matrix.lockerId,
      expectedBoxId: frame.boxId,
      forceInvalid: config.forceInvalidToken,
      forceExpired: config.forceExpiredToken,
    );
    if (!tokenCheck.ok) {
      return _errorFrame(
        sequenceNumber: frame.sequenceNumber,
        orderId: frame.orderId,
        lockerId: frame.lockerId,
        boxId: frame.boxId,
        code: tokenCheck.error ?? McuErrorCode.invalidToken,
        message: tokenCheck.message ?? 'token',
      );
    }

    if (config.forceBusy || matrix.anyBusy) {
      return _errorFrame(
        sequenceNumber: frame.sequenceNumber,
        orderId: frame.orderId,
        lockerId: frame.lockerId,
        boxId: frame.boxId,
        code: McuErrorCode.lockerBusy,
        message: 'locker busy',
      );
    }

    final box = matrix.find(frame.boxId);
    if (box == null) {
      return _errorFrame(
        sequenceNumber: frame.sequenceNumber,
        orderId: frame.orderId,
        lockerId: frame.lockerId,
        boxId: frame.boxId,
        code: McuErrorCode.invalidBox,
        message: 'box not found',
      );
    }

    if (box.doorState == DoorState.open) {
      return _errorFrame(
        sequenceNumber: frame.sequenceNumber,
        orderId: frame.orderId,
        lockerId: frame.lockerId,
        boxId: frame.boxId,
        code: McuErrorCode.doorAlreadyOpen,
        message: 'door already open',
      );
    }

    if (box.isEmpty) {
      return _errorFrame(
        sequenceNumber: frame.sequenceNumber,
        orderId: frame.orderId,
        lockerId: frame.lockerId,
        boxId: frame.boxId,
        code: McuErrorCode.boxEmpty,
        message: 'box empty',
      );
    }

    if (config.forceDisconnectDuringOpen) {
      state.bleConnected = false;
      logger.log(
        event: 'DISCONNECT_DURING_OPEN',
        box: box.boxId,
        result: McuErrorCode.disconnectDuringOpen.wireName,
      );
      return null;
    }

    box.busy = true;
    box.lastPacket = 'OPEN_BOX';
    try {
      motors.start(box);
      await doors.open(box);
      motors.stop(box);
      box.busy = false;
      box.reserved = false;
      logger.log(
        event: 'OPEN_OK',
        packet: 'OPEN_ACK',
        box: box.boxId,
        door: box.doorState.name,
        lock: box.lockState.name,
        result: 'opened',
      );
      return _reply(
        frame,
        McuPacketType.openAck,
        payload: codec.jsonPayload({
          'opened': true,
          'doorState': 'OPEN',
          'boxStatus': box.isEmpty ? 'EMPTY' : 'AVAILABLE',
        }),
      );
    } catch (error) {
      box.busy = false;
      box.lastError = error.toString();
      final code = errors.fromException(error);
      state.lastError = code.wireName;
      return _errorFrame(
        sequenceNumber: frame.sequenceNumber,
        orderId: frame.orderId,
        lockerId: frame.lockerId,
        boxId: frame.boxId,
        code: code,
        message: error.toString(),
      );
    }
  }

  Uint8List _handleStatus(McuFrame frame) {
    final box = frame.boxId.isEmpty ? null : matrix.find(frame.boxId);
    final door = box == null
        ? 'UNKNOWN'
        : (sensors.isDoorOpen(box) ? 'OPEN' : 'CLOSED');
    return _reply(
      frame,
      McuPacketType.statusResponse,
      payload: codec.jsonPayload({
        'doorState': door,
        'boxStatus': box == null
            ? 'UNKNOWN'
            : (box.isEmpty ? 'EMPTY' : 'AVAILABLE'),
        'batteryMv': state.batteryLevel * 40,
        'uptimeSeconds': state.uptimeSeconds,
        'temperatureC': state.temperature,
        'rssi': state.rssi,
        'firmwareVersion': state.firmwareVersion,
        'mcuId': state.mcuId,
      }),
    );
  }
}
