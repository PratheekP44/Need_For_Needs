/// Environment configuration skeleton.
///
/// Do not place secrets or live endpoints here yet.
enum AppEnvironment {
  development,
  staging,
  production,
}

class EnvConfig {
  const EnvConfig({
    required this.environment,
  });

  final AppEnvironment environment;

  static const EnvConfig development = EnvConfig(
    environment: AppEnvironment.development,
  );
}
