import 'package:flutter/foundation.dart';

/// Environment configuration for API integration.
///
/// Single source of truth for the API base URL used by [ApiClient],
/// inventory SSE, and media URL resolution.
///
/// Defaults:
/// - Development (Flutter Web / Android / iOS / desktop): Render production URL
///   unless an explicit override is set
/// - Production (release builds): `https://need-for-needs.onrender.com`
///
/// Overrides (compile-time):
/// - `--dart-define=API_BASE_URL=https://...` — full URL override
/// - `--dart-define=LAN_IP=192.168.x.x` — Android debug → local LAN backend
/// - `--dart-define=API_BASE_URL=http://127.0.0.1:5000` — Web/desktop → local Node
///
/// Razorpay Key Secret must NEVER live here — only the backend holds it.
/// Flutter receives `keyId` from `POST /payment/create-order`.
enum AppEnvironment {
  development,
  staging,
  production,
}

class EnvConfig {
  const EnvConfig({
    required this.environment,
    required this.apiBaseUrl,
  });

  final AppEnvironment environment;
  final String apiBaseUrl;

  /// Alias for [apiBaseUrl] — used by media URL resolution and docs.
  String get baseUrl => apiBaseUrl;

  /// Full URL override: `--dart-define=API_BASE_URL=...`
  static const String apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Machine LAN IP for Android debug → local Node backend.
  /// Only applied when explicitly set: `--dart-define=LAN_IP=192.168.1.19`
  ///
  /// Empty default (not a hardcoded LAN) so debug builds hit Render after deploy.
  static const String lanIp = String.fromEnvironment('LAN_IP');

  /// Legacy local default — only used when explicitly requested via API_BASE_URL.
  static const String webDevBaseUrl = 'http://127.0.0.1:5000';
  static const String productionBaseUrl =
      'https://need-for-needs.onrender.com';

  static String get androidDevBaseUrl => 'http://$lanIp:5000';

  /// Development — defaults to Render; local backends require an explicit define.
  static EnvConfig get development {
    final url = apiBaseUrlOverride.isNotEmpty
        ? apiBaseUrlOverride
        : _developmentDefaultUrl;
    return EnvConfig(
      environment: AppEnvironment.development,
      apiBaseUrl: url,
    );
  }

  static String get _developmentDefaultUrl {
    // Flutter Web `flutter run -d chrome` is DEBUG (kReleaseMode=false).
    // Previously Web always used 127.0.0.1:5000 → false "offline" when local
    // Node is not running. Match Android: default to Render.
    if (kIsWeb) return productionBaseUrl;
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Explicit LAN_IP → local backend. Otherwise use deployed Render API.
      if (lanIp.isNotEmpty) return androidDevBaseUrl;
      return productionBaseUrl;
    }
    // iOS simulator / desktop debug — Render by default (override for local).
    return productionBaseUrl;
  }

  /// Production — Render backend.
  static EnvConfig get production {
    final url = apiBaseUrlOverride.isNotEmpty
        ? apiBaseUrlOverride
        : productionBaseUrl;
    return EnvConfig(
      environment: AppEnvironment.production,
      apiBaseUrl: url,
    );
  }

  /// Release → production; debug/profile → development defaults.
  static EnvConfig resolve() {
    final cfg = kReleaseMode ? production : development;
    // Temporary diagnose log (safe — URL + mode only, no secrets).
    // ignore: avoid_print
    print(
      '[EnvConfig] kReleaseMode=$kReleaseMode '
      'kIsWeb=$kIsWeb '
      'environment=${cfg.environment.name} '
      'baseUrl=${cfg.apiBaseUrl} '
      'API_BASE_URL_override=${apiBaseUrlOverride.isNotEmpty} '
      'LAN_IP_set=${lanIp.isNotEmpty}',
    );
    return cfg;
  }
}
