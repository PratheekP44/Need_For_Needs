import 'dart:convert';
import 'dart:math';

import 'package:geolocator/geolocator.dart';

/// Device GPS helpers for real locker distances.
class LocationService {
  Future<bool> ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<Position?> currentPosition() async {
    final ok = await ensurePermission();
    if (!ok) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Haversine distance in meters (also available via Geolocator).
  int distanceMeters({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    return Geolocator.distanceBetween(fromLat, fromLng, toLat, toLng).round();
  }

  /// Fallback when GPS unavailable — still not a fixed campus mock list.
  int approximateFromOrigin({
    required double toLat,
    required double toLng,
    double originLat = 12.9716,
    double originLng = 77.5946,
  }) {
    final dLat = _toRad(toLat - originLat);
    final dLng = _toRad(toLng - originLng);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(originLat)) *
            cos(_toRad(toLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return (6371000 * c).round();
  }

  double _toRad(double deg) => deg * pi / 180;
}

/// JSON helpers for API maps.
Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected object, got ${value.runtimeType}');
}

List<dynamic> asList(dynamic value) {
  if (value is List) return value;
  return const [];
}

String? asString(dynamic value) => value?.toString();

double asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int asInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String prettyJson(Object? value) {
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
  }
}
