import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/ux.dart';

class AdminState {
  const AdminState({
    this.stats = const AdminStats(
      totalLockers: 0,
      availableLockers: 0,
      ordersToday: 0,
      revenueToday: 0,
      inventoryStatus: 'Loading…',
    ),
    this.lockers = const [],
    this.inventory = const [],
    this.orders = const [],
    this.isLoading = true,
    this.error,
  });

  final AdminStats stats;
  final List<Locker> lockers;
  final List<InventoryRow> inventory;
  final List<OrderSummary> orders;
  final bool isLoading;
  final String? error;
}

class AdminViewModel extends Notifier<AdminState> {
  @override
  AdminState build() {
    ref.listen(authSessionProvider, (prev, next) {
      if (next.isAdmin) refresh();
    });
    Future.microtask(refresh);
    return const AdminState();
  }

  Future<void> refresh() async {
    if (!ref.read(authSessionProvider).isAdmin) {
      state = const AdminState(isLoading: false, error: 'Admin role required');
      return;
    }
    state = AdminState(
      stats: state.stats,
      lockers: state.lockers,
      inventory: state.inventory,
      orders: state.orders,
      isLoading: true,
    );
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final results = await Future.wait([
        catalog.fetchAdminStats(),
        ref.read(lockerRepositoryProvider).list(),
        catalog.listInventory(),
        ref.read(orderRepositoryProvider).list(),
      ]);
      state = AdminState(
        stats: results[0] as AdminStats,
        lockers: results[1] as List<Locker>,
        inventory: results[2] as List<InventoryRow>,
        orders: results[3] as List<OrderSummary>,
        isLoading: false,
      );
    } catch (e) {
      state = AdminState(isLoading: false, error: userFacingError(e));
    }
  }
}

final adminViewModelProvider =
    NotifierProvider<AdminViewModel, AdminState>(AdminViewModel.new);

String formatInr(num amount) => MoneyFormat.format(amount);
