import 'package:flutter/foundation.dart';

/// Environment configuration for API integration.
///
/// Single source of truth for the API base URL used by [ApiClient],
/// inventory SSE, and media URL resolution.
///
/// Defaults:
/// - Development (Flutter Web / desktop / iOS simulator): `http://127.0.0.1:5000`
/// - Development (Android): `http://<LAN_IP>:5000`
/// - Production (release builds): `https://need-for-needs.onrender.com`
///
/// Overrides (compile-time):
/// - `--dart-define=API_BASE_URL=https://...` — full URL override
/// - `--dart-define=LAN_IP=192.168.x.x` — Android LAN host only
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
    this.unlockJwtSecret = '',
  });

  final AppEnvironment environment;
  final String apiBaseUrl;

  /// Dedicated Unlock JWT HS256 secret (`UNLOCK_JWT_SECRET`).
  /// Must match the server value. Never reuse auth JWT secrets.
  final String unlockJwtSecret;

  /// Alias for [apiBaseUrl] — used by media URL resolution and docs.
  String get baseUrl => apiBaseUrl;

  /// Full URL override: `--dart-define=API_BASE_URL=...`
  static const String apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Machine LAN IP for Android debug builds.
  /// Override: `--dart-define=LAN_IP=192.168.1.19`
  static const String lanIp = String.fromEnvironment(
    'LAN_IP',
    defaultValue: '192.168.1.19',
  );

  /// Unlock JWT secret: `--dart-define=UNLOCK_JWT_SECRET=...`
  static const String unlockJwtSecretDefine = String.fromEnvironment(
    'UNLOCK_JWT_SECRET',
  );

  static const String webDevBaseUrl = 'http://127.0.0.1:5000';
  static const String productionBaseUrl =
      'https://need-for-needs.onrender.com';

  static String get androidDevBaseUrl => 'http://$lanIp:5000';

  /// Development — Web/desktop use loopback; Android uses LAN IP.
  static EnvConfig get development {
    final url = apiBaseUrlOverride.isNotEmpty
        ? apiBaseUrlOverride
        : _developmentDefaultUrl;
    return EnvConfig(
      environment: AppEnvironment.development,
      apiBaseUrl: url,
      unlockJwtSecret: unlockJwtSecretDefine,
    );
  }

  static String get _developmentDefaultUrl {
    if (kIsWeb) return webDevBaseUrl;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidDevBaseUrl;
    }
    return webDevBaseUrl;
  }

  /// Production — Render backend.
  static EnvConfig get production {
    final url = apiBaseUrlOverride.isNotEmpty
        ? apiBaseUrlOverride
        : productionBaseUrl;
    return EnvConfig(
      environment: AppEnvironment.production,
      apiBaseUrl: url,
      unlockJwtSecret: unlockJwtSecretDefine,
    );
  }

  /// Release → production; debug/profile → development.
  static EnvConfig resolve() {
    if (kReleaseMode) return production;
    return development;
  }
}
