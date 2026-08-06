/// Discovered or known BLE peripheral (transport-level).
class BleDevice {
  const BleDevice({
    required this.id,
    required this.name,
    this.rssi,
    this.advertisementName,
    this.isConnectable = true,
  });

  /// Platform device identifier (remoteId / MAC / UUID).
  final String id;

  /// Best-effort display name.
  final String name;

  final int? rssi;
  final String? advertisementName;
  final bool isConnectable;

  BleDevice copyWith({
    String? id,
    String? name,
    int? rssi,
    String? advertisementName,
    bool? isConnectable,
  }) {
    return BleDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      advertisementName: advertisementName ?? this.advertisementName,
      isConnectable: isConnectable ?? this.isConnectable,
    );
  }

  @override
  String toString() => 'BleDevice(id=$id, name=$name, rssi=$rssi)';
}
