import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/providers/catalog_refresh.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';

/// Root application widget for Need For Needs.
class NeedForNeedsApp extends ConsumerWidget {
  const NeedForNeedsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep inventory SSE alive for authenticated sessions.
    ref.watch(inventoryRealtimeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
