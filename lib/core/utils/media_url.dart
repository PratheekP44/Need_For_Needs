import '../config/env_config.dart';

/// Resolves product / media paths against [EnvConfig.baseUrl].
///
/// Rules:
/// - empty → empty
/// - already `http://` or `https://` → unchanged
/// - otherwise prepend [EnvConfig.baseUrl] (or [apiBaseUrl] override)
String resolveMediaUrl(String? path, {String? apiBaseUrl}) {
  final raw = (path ?? '').trim();
  if (raw.isEmpty) return '';
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  final base = (apiBaseUrl ?? EnvConfig.resolve().baseUrl)
      .replaceAll(RegExp(r'/$'), '');
  return raw.startsWith('/') ? '$base$raw' : '$base/$raw';
}
