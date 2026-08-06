/// Environment configuration for API integration.
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

  static const EnvConfig development = EnvConfig(
    environment: AppEnvironment.development,
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:5000',
    ),
  );

  static const EnvConfig production = EnvConfig(
    environment: AppEnvironment.production,
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.example.com',
    ),
  );
}
