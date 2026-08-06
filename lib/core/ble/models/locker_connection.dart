import 'ble_device.dart';
import 'locker_state.dart';

/// Active or last locker BLE connection snapshot.
class LockerConnection {
  const LockerConnection({
    required this.device,
    required this.state,
    this.lockerId,
    this.boxId,
    this.orderId,
    this.mtu,
    this.authenticated = false,
    this.lastError,
  });

  final BleDevice device;
  final LockerState state;
  final String? lockerId;
  final String? boxId;
  final String? orderId;
  final int? mtu;
  final bool authenticated;
  final String? lastError;

  static LockerConnection empty() => LockerConnection(
        device: const BleDevice(id: '', name: ''),
        state: LockerState.disconnected,
      );

  LockerConnection copyWith({
    BleDevice? device,
    LockerState? state,
    String? lockerId,
    String? boxId,
    String? orderId,
    int? mtu,
    bool? authenticated,
    String? lastError,
  }) {
    return LockerConnection(
      device: device ?? this.device,
      state: state ?? this.state,
      lockerId: lockerId ?? this.lockerId,
      boxId: boxId ?? this.boxId,
      orderId: orderId ?? this.orderId,
      mtu: mtu ?? this.mtu,
      authenticated: authenticated ?? this.authenticated,
      lastError: lastError,
    );
  }
}
