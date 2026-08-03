import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';
import '../services/app_service.dart';

/// Core Riverpod provider skeleton.
final envConfigProvider = Provider<EnvConfig>((ref) {
  return EnvConfig.development;
});

final appServiceProvider = Provider<AppService>((ref) {
  return const AppService();
});
