import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models.dart';
import '../../../core/providers/core_providers.dart';

class OrdersState {
  const OrdersState({
    this.orders = const [],
    this.isLoading = true,
    this.error,
  });

  final List<OrderSummary> orders;
  final bool isLoading;
  final String? error;
}

class OrdersViewModel extends Notifier<OrdersState> {
  @override
  OrdersState build() {
    ref.listen(authSessionProvider, (prev, next) {
      if (next.isAuthenticated) refresh();
    });
    Future.microtask(refresh);
    return const OrdersState();
  }

  Future<void> refresh() async {
    if (!ref.read(authSessionProvider).isAuthenticated) {
      state = const OrdersState(isLoading: false);
      return;
    }
    state = const OrdersState(isLoading: true);
    try {
      final orders = await ref.read(orderRepositoryProvider).list();
      state = OrdersState(orders: orders, isLoading: false);
    } catch (e) {
      state = OrdersState(isLoading: false, error: e.toString());
    }
  }
}

final ordersViewModelProvider =
    NotifierProvider<OrdersViewModel, OrdersState>(OrdersViewModel.new);
