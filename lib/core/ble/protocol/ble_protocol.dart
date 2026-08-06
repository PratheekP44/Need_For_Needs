import 'dart:async';
import 'dart:typed_data';

import '../managers/connection_manager.dart';
import '../managers/retry_manager.dart';
import '../managers/sequence_manager.dart';
import '../managers/timeout_manager.dart';
import '../models/packet.dart';
import '../models/packet_payload.dart';
import '../models/packet_result.dart';
import 'packet_codec.dart';
import 'packet_types.dart';

/// Packet layer — encode/decode, validate, sequence, retry, timeout.
///
/// Does not own Bluetooth scanning/connect; uses [ConnectionManager] for I/O.
class BleProtocol {
  BleProtocol({
    required this.connection,
    PacketCodec? codec,
    SequenceManager? sequenceManager,
    RetryManager? retryManager,
    TimeoutManager? timeoutManager,
  })  : _codec = codec ?? const PacketCodec(),
        sequence = sequenceManager ?? SequenceManager(),
        retry = retryManager ?? RetryManager(),
        timeouts = timeoutManager ?? const TimeoutManager();

  final ConnectionManager connection;
  final PacketCodec _codec;

  /// Exposed for tests and advanced orchestration.
  final SequenceManager sequence;
  final RetryManager retry;
  final TimeoutManager timeouts;

  final _packetController = StreamController<Packet>.broadcast();

  StreamSubscription<Uint8List>? _notifySub;
  Completer<Packet>? _pending;
  BlePacketType? _expectedType;
  int? _expectedSeq;

  /// Decoded inbound packets (including unsolicited ERROR / HEARTBEAT).
  Stream<Packet> get packetStream => _packetController.stream;

  /// Subscribe to transport notifications (call after connect).
  void attachNotifications() {
    _notifySub?.cancel();
    _notifySub = connection.notificationStream.listen(_onNotification);
  }

  void _onNotification(Uint8List raw) {
    try {
      final packet = _codec.decode(raw);
      sequence.acceptInbound(packet.header.sequenceNumber);
      _packetController.add(packet);

      final pending = _pending;
      if (pending != null &&
          !pending.isCompleted &&
          (_expectedSeq == null ||
              packet.header.sequenceNumber == _expectedSeq) &&
          (_expectedType == null ||
              packet.packetType == _expectedType ||
              packet.packetType == BlePacketType.error)) {
        pending.complete(packet);
      }
    } catch (error) {
      final pending = _pending;
      if (pending != null && !pending.isCompleted) {
        pending.completeError(error);
      }
    }
  }

  /// Validates and encodes a packet to bytes (sets checksum).
  Uint8List encode(Packet packet) {
    final errors = packet.validate();
    if (errors.isNotEmpty) {
      throw FormatException(errors.join('; '));
    }
    return _codec.encode(packet);
  }

  Packet decode(Uint8List frame) => _codec.decode(frame);

  Future<PacketResult> ping({String lockerId = ''}) {
    return exchange(
      type: BlePacketType.ping,
      expect: BlePacketType.pong,
      lockerId: lockerId,
    );
  }

  Future<PacketResult> authenticate({
    required String orderId,
    required String lockerId,
    required String boxId,
    required String collectionToken,
    PacketPayload? payload,
  }) {
    return exchange(
      type: BlePacketType.auth,
      expect: BlePacketType.authAck,
      orderId: orderId,
      lockerId: lockerId,
      boxId: boxId,
      collectionToken: collectionToken,
      payload: payload ??
          PacketPayload.auth(
            tokenExpiresAt: null,
            phoneNonce: DateTime.now().millisecondsSinceEpoch.toString(),
          ),
    );
  }

  Future<PacketResult> openBox({
    required String orderId,
    required String lockerId,
    required String boxId,
    required String collectionToken,
  }) {
    return exchange(
      type: BlePacketType.openBox,
      expect: BlePacketType.openAck,
      orderId: orderId,
      lockerId: lockerId,
      boxId: boxId,
      collectionToken: collectionToken,
      payload: PacketPayload.openBox(),
    );
  }

  Future<PacketResult> requestStatus({
    required String lockerId,
    String boxId = '',
  }) {
    return exchange(
      type: BlePacketType.status,
      expect: BlePacketType.statusResponse,
      lockerId: lockerId,
      boxId: boxId,
      payload: PacketPayload.statusRequest(),
    );
  }

  Future<PacketResult> heartbeat({String lockerId = ''}) {
    return exchange(
      type: BlePacketType.heartbeat,
      expect: BlePacketType.heartbeat,
      lockerId: lockerId,
      payload: PacketPayload.heartbeat(),
    );
  }

  Future<void> sendDisconnect({String lockerId = ''}) async {
    final packet = Packet.build(
      type: BlePacketType.disconnect,
      sequenceNumber: sequence.next(),
      lockerId: lockerId,
    );
    await connection.write(encode(packet));
  }

  /// Core request/response with retry + timeout.
  Future<PacketResult> exchange({
    required BlePacketType type,
    required BlePacketType expect,
    String orderId = '',
    String lockerId = '',
    String boxId = '',
    String collectionToken = '',
    PacketPayload? payload,
  }) async {
    var attempt = 0;
    Packet? lastRequest;

    while (true) {
      attempt += 1;
      final seq = sequence.next();
      final request = Packet.build(
        type: type,
        sequenceNumber: seq,
        orderId: orderId,
        lockerId: lockerId,
        boxId: boxId,
        collectionToken: collectionToken,
        payload: payload,
      );
      lastRequest = request;

      try {
        final response = await _sendAndWait(
          request: request,
          expect: expect,
          timeout: timeouts.responseTimeout(type),
        );

        if (response.packetType == BlePacketType.error) {
          final map = response.payload.asJsonMap();
          final codeNum = map?['code'];
          final code = codeNum is int ? BleErrorCode.fromCode(codeNum) : null;
          final canRetry = retry.shouldRetry(
            attempt: attempt,
            packetType: type,
            errorCode: code,
          );
          if (canRetry) {
            await Future<void>.delayed(retry.delayForAttempt(attempt));
            continue;
          }
          return PacketResult.failure(
            request: request,
            response: response,
            errorCode: code,
            message: map?['message']?.toString() ?? 'ERROR packet',
          );
        }

        return PacketResult.ok(request: request, response: response);
      } on TimeoutException {
        final canRetry = retry.shouldRetry(
          attempt: attempt,
          packetType: type,
          errorCode: BleErrorCode.bleTimeout,
        );
        if (!canRetry) {
          return PacketResult.failure(
            request: lastRequest,
            errorCode: BleErrorCode.bleTimeout,
            message: 'BLE_TIMEOUT',
            timedOut: true,
          );
        }
        await Future<void>.delayed(retry.delayForAttempt(attempt));
      } on FormatException catch (error) {
        final crc = error.message.contains('CRC_FAILED');
        final canRetry = retry.shouldRetry(
          attempt: attempt,
          packetType: type,
          errorCode: crc ? BleErrorCode.crcFailed : null,
          fatal: !crc,
        );
        if (!canRetry) {
          return PacketResult.failure(
            request: lastRequest,
            errorCode: crc ? BleErrorCode.crcFailed : null,
            message: error.message,
          );
        }
        await Future<void>.delayed(retry.delayForAttempt(attempt));
      } catch (error) {
        return PacketResult.failure(
          request: lastRequest,
          message: error.toString(),
        );
      }
    }
  }

  Future<Packet> _sendAndWait({
    required Packet request,
    required BlePacketType expect,
    required Duration timeout,
  }) async {
    final completer = Completer<Packet>();
    _pending = completer;
    _expectedType = expect;
    _expectedSeq = request.header.sequenceNumber;

    try {
      await connection.write(encode(request));
      return await completer.future.timeout(timeout);
    } finally {
      if (identical(_pending, completer)) {
        _pending = null;
        _expectedType = null;
        _expectedSeq = null;
      }
    }
  }

  Future<void> dispose() async {
    await _notifySub?.cancel();
    await _packetController.close();
  }
}
