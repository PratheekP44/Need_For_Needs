import 'package:flutter/foundation.dart';

/// Shared validation for permanent product [imageUrl] values.
///
/// Source of truth is MongoDB `imageUrl` (public http(s) URL).
abstract final class ProductImageUrlRules {
  /// Returns a user-facing error, or `null` if acceptable.
  /// Empty is allowed (no image).
  static String? validationError(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    if (value.length > 1000) {
      return 'Image URL is too long';
    }
    final lower = value.toLowerCase();
    if (lower.startsWith('file:') ||
        lower.startsWith('content:') ||
        lower.startsWith('data:')) {
      return 'This image URL must be publicly accessible.';
    }
    // Legacy server uploads (resolved against API base on the client).
    if (value.startsWith('/uploads/')) return null;

    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return 'Image URL must be a valid http(s) link';
    }
    if (_isPrivateOrLocalHost(uri.host)) {
      return 'This image URL must be publicly accessible.';
    }
    return null;
  }

  static bool isAcceptable(String? raw) => validationError(raw) == null;

  static bool _isPrivateOrLocalHost(String host) {
    final h = host.trim().toLowerCase().replaceAll(RegExp(r'\.+$'), '');
    if (h.isEmpty) return true;
    if (h == 'localhost' ||
        h == '127.0.0.1' ||
        h == '0.0.0.0' ||
        h == '::1' ||
        h.endsWith('.local')) {
      return true;
    }
    final parts = h.split('.');
    if (parts.length == 4 && parts.every((p) => int.tryParse(p) != null)) {
      final a = int.parse(parts[0]);
      final b = int.parse(parts[1]);
      if (a == 10 || a == 127 || a == 0) return true;
      if (a == 169 && b == 254) return true;
      if (a == 192 && b == 168) return true;
      if (a == 172 && b >= 16 && b <= 31) return true;
    }
    return false;
  }

  static void debugLogLoadFailure(String? url, Object error) {
    if (!kDebugMode) return;
    // ignore: avoid_print
    print('[ProductImage] load failed url=$url error=$error');
  }
}
