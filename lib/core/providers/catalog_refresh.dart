import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/inventory_events_client.dart';
import 'core_providers.dart';
import '../../features/admin/viewmodels/admin_viewmodel.dart';
import '../../features/cart/viewmodels/cart_viewmodel.dart';
import '../../features/home/viewmodels/home_viewmodel.dart';
import '../../features/orders/viewmodels/orders_viewmodel.dart';

/// Bumped whenever inventory changes so detail FutureProviders rebuild.
class InventoryEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final inventoryEpochProvider =
    NotifierProvider<InventoryEpoch, int>(InventoryEpoch.new);

/// Refreshes customer + admin surfaces after payment / inventory SSE events.
/// Prefer this for payment/cancel — not after every cart tap (optimistic UI).
Future<void> refreshCatalogSurfaces(dynamic ref) async {
  ref.read(inventoryEpochProvider.notifier).bump();
  final futures = <Future<void>>[
    ref.read(cartViewModelProvider.notifier).refresh(),
    ref.read(homeViewModelProvider.notifier).refresh(),
    ref.read(ordersViewModelProvider.notifier).refresh(),
  ];
  if (ref.read(authSessionProvider).isAdmin) {
    futures.add(ref.read(adminViewModelProvider.notifier).refresh());
  }
  await Future.wait(futures);
}

/// Lightweight bump so product-detail FutureProviders rebuild without
/// re-fetching the entire home catalog.
void bumpInventoryEpoch(dynamic ref) {
  ref.read(inventoryEpochProvider.notifier).bump();
}

/// Keeps an SSE subscription alive while the user is authenticated.
class InventoryRealtimeController extends Notifier<int> {
  InventoryEventsClient? _client;

  @override
  int build() {
    ref.listen(authSessionProvider, (prev, next) {
      if (next.isAuthenticated) {
        _start();
      } else {
        _stop();
      }
    });
    ref.onDispose(_stop);
    if (ref.read(authSessionProvider).isAuthenticated) {
      Future.microtask(_start);
    }
    return 0;
  }

  void _start() {
    _stop();
    final containerRef = ref;
    _client = InventoryEventsClient(
      session: containerRef.read(sessionStoreProvider),
      config: containerRef.read(envConfigProvider),
      onEvent: (event) {
        final type = event['type']?.toString();
        if (type == 'inventory_updated') {
          // ignore: discarded_futures
          refreshCatalogSurfaces(containerRef);
        }
      },
    );
    // ignore: discarded_futures
    _client!.start();
  }

  void _stop() {
    // ignore: discarded_futures
    _client?.stop();
    _client = null;
  }
}

/// Side-effect provider: watch once from the app root to start SSE.
final inventoryRealtimeProvider =
    NotifierProvider<InventoryRealtimeController, int>(
  InventoryRealtimeController.new,
);
