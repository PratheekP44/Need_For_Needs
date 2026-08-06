import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/data/models.dart';
import '../../../core/providers/core_providers.dart';

class CartState {
  const CartState({
    this.items = const [],
    this.subtotal = 0,
    this.tax = 0,
    this.grandTotal = 0,
    this.isLoading = false,
    this.error,
  });

  final List<CartLine> items;
  final double subtotal;
  final double tax;
  final double grandTotal;
  final bool isLoading;
  final String? error;

  CartState copyWith({
    List<CartLine>? items,
    double? subtotal,
    double? tax,
    double? grandTotal,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CartState(
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      grandTotal: grandTotal ?? this.grandTotal,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CartViewModel extends Notifier<CartState> {
  @override
  CartState build() {
    ref.listen(authSessionProvider, (prev, next) {
      if (next.isAuthenticated && next.user?.isAdmin != true) {
        refresh();
      } else if (!next.isAuthenticated) {
        state = const CartState();
      }
    });
    Future.microtask(refresh);
    return const CartState();
  }

  void _apply(
    ({
      List<CartLine> items,
      double subtotal,
      double tax,
      double grandTotal,
    }) cart,
  ) {
    state = CartState(
      items: cart.items,
      subtotal: cart.subtotal,
      tax: cart.tax,
      grandTotal: cart.grandTotal,
    );
  }

  Future<void> refresh() async {
    final auth = ref.read(authSessionProvider);
    if (!auth.isAuthenticated || auth.isAdmin) {
      state = const CartState();
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cart = await ref.read(cartRepositoryProvider).getCart();
      _apply(cart);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addStock(
    Product product, {
    int quantity = 1,
  }) async {
    if (!product.hasCartMapping) {
      throw ApiException(
        'This product is unavailable and cannot be added to cart',
      );
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cart = await ref.read(cartRepositoryProvider).add(
            itemId: product.id,
            lockerId: product.lockerId.isNotEmpty ? product.lockerId : null,
            quantity: quantity,
          );
      _apply(cart);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }

  Future<void> setQuantity(String cartItemId, int quantity) async {
    if (quantity < 1) {
      await remove(cartItemId);
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cart = await ref.read(cartRepositoryProvider).update(
            cartItemId: cartItemId,
            quantity: quantity,
          );
      _apply(cart);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }

  Future<void> remove(String cartItemId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cart = await ref.read(cartRepositoryProvider).remove(cartItemId);
      _apply(cart);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }

  Future<void> clearCart() async {
    if (state.items.isEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ids = state.items.map((e) => e.cartItemId).toList();
      for (final id in ids) {
        await ref.read(cartRepositoryProvider).remove(id);
      }
      await refresh();
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }
}

final cartViewModelProvider =
    NotifierProvider<CartViewModel, CartState>(CartViewModel.new);
