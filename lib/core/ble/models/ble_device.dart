/// Discovered or known BLE peripheral (transport-level).
class BleDevice {
  const BleDevice({
    required this.id,
    required this.name,
    this.rssi,
    this.advertisementName,
    this.isConnectable = true,
    this.manufacturerDataHex = const [],
    this.serviceUuids = const [],
    this.isTargetLocker = false,
  });

  /// Platform device identifier (remoteId / MAC / UUID).
  final String id;

  /// Best-effort display name.
  final String name;

  final int? rssi;
  final String? advertisementName;
  final bool isConnectable;

  /// Manufacturer-specific data as hex strings (one per company ID entry).
  final List<String> manufacturerDataHex;

  /// Advertised service UUIDs (lower-case).
  final List<String> serviceUuids;

  /// True when name / advertised service matches the Campus Essentials locker.
  final bool isTargetLocker;

  BleDevice copyWith({
    String? id,
    String? name,
    int? rssi,
    String? advertisementName,
    bool? isConnectable,
    List<String>? manufacturerDataHex,
    List<String>? serviceUuids,
    bool? isTargetLocker,
  }) {
    return BleDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      advertisementName: advertisementName ?? this.advertisementName,
      isConnectable: isConnectable ?? this.isConnectable,
      manufacturerDataHex: manufacturerDataHex ?? this.manufacturerDataHex,
      serviceUuids: serviceUuids ?? this.serviceUuids,
      isTargetLocker: isTargetLocker ?? this.isTargetLocker,
    );
  }

  @override
  String toString() =>
      'BleDevice(id=$id, name=$name, rssi=$rssi, target=$isTargetLocker)';
}
