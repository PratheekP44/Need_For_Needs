import '../protocol/packet_types.dart';
import 'packet.dart';

/// Outcome of a request/response exchange at the protocol layer.
class PacketResult {
  const PacketResult({
    required this.success,
    this.request,
    this.response,
    this.errorCode,
    this.message,
    this.timedOut = false,
  });

  factory PacketResult.ok({
    required Packet request,
    required Packet response,
  }) =>
      PacketResult(
        success: true,
        request: request,
        response: response,
      );

  factory PacketResult.failure({
    Packet? request,
    Packet? response,
    BleErrorCode? errorCode,
    String? message,
    bool timedOut = false,
  }) =>
      PacketResult(
        success: false,
        request: request,
        response: response,
        errorCode: errorCode,
        message: message,
        timedOut: timedOut,
      );

  final bool success;
  final Packet? request;
  final Packet? response;
  final BleErrorCode? errorCode;
  final String? message;
  final bool timedOut;

  Map<String, Object?>? get responsePayload => response?.payload.asJsonMap();
}
