'use strict';

/**
 * Haversine distance in meters between two lat/lng points.
 */
function calculateDistanceInMeters(origin, destination) {
  if (
    !origin ||
    origin.latitude == null ||
    origin.longitude == null ||
    !destination ||
    destination.latitude == null ||
    destination.longitude == null
  ) {
    return null;
  }

  const toRad = (deg) => (Number(deg) * Math.PI) / 180;
  const lat1 = Number(origin.latitude);
  const lon1 = Number(origin.longitude);
  const lat2 = Number(destination.latitude);
  const lon2 = Number(destination.longitude);

  if (![lat1, lon1, lat2, lon2].every((n) => Number.isFinite(n))) {
    return null;
  }

  const R = 6371000;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

function parseOrigin(queryOrOrigin) {
  if (!queryOrOrigin) return null;
  if (
    typeof queryOrOrigin === 'object' &&
    queryOrOrigin.latitude != null &&
    queryOrOrigin.longitude != null
  ) {
    return {
      latitude: Number(queryOrOrigin.latitude),
      longitude: Number(queryOrOrigin.longitude),
    };
  }
  const lat = queryOrOrigin.lat ?? queryOrOrigin.latitude;
  const lng = queryOrOrigin.lng ?? queryOrOrigin.longitude;
  if (lat == null || lng == null) return null;
  const latitude = Number(lat);
  const longitude = Number(lng);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  return { latitude, longitude };
}

function withDistance(locker, origin = null) {
  const parsed = parseOrigin(origin);
  const distanceInMeters = calculateDistanceInMeters(parsed, {
    latitude: locker.latitude,
    longitude: locker.longitude,
  });

  return {
    ...locker,
    distanceInMeters: distanceInMeters == null ? null : distanceInMeters,
  };
}

module.exports = {
  calculateDistanceInMeters,
  parseOrigin,
  withDistance,
};
