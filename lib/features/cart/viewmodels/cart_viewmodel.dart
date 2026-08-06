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
    this.isMutating = false,
    this.error,
  });

  final List<CartLine> items;
  final double subtotal;
  final double tax;
  final double grandTotal;

  /// True only while the full cart is being fetched (initial / pull).
  final bool isLoading;

  /// True while a background add/update/remove is in flight (UI stays interactive).
  final bool isMutating;
  final String? error;

  int get totalQuantity =>
      items.fold<int>(0, (sum, line) => sum + line.quantity);

  int quantityForProduct(String productId) => items
      .where((line) => line.product.id == productId)
      .fold<int>(0, (sum, line) => sum + line.quantity);

  CartState copyWith({
    List<CartLine>? items,
    double? subtotal,
    double? tax,
    double? grandTotal,
    bool? isLoading,
    bool? isMutating,
    String? error,
    bool clearError = false,
  }) {
    return CartState(
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      grandTotal: grandTotal ?? this.grandTotal,
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CartViewModel extends Notifier<CartState> {
  int _optimisticSeq = 0;

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
    }) cart, {
    bool clearError = true,
  }) {
    state = CartState(
      items: cart.items,
      subtotal: cart.subtotal,
      tax: cart.tax,
      grandTotal: cart.grandTotal,
      isLoading: false,
      isMutating: false,
      error: clearError ? null : state.error,
    );
  }

  CartState _retotal(List<CartLine> items) {
    var subtotal = 0.0;
    for (final line in items) {
      subtotal += line.computedLineTotal;
    }
    final tax = state.subtotal > 0
        ? (state.tax / state.subtotal) * subtotal
        : 0.0;
    return state.copyWith(
      items: items,
      subtotal: double.parse(subtotal.toStringAsFixed(2)),
      tax: double.parse(tax.toStringAsFixed(2)),
      grandTotal: double.parse((subtotal + tax).toStringAsFixed(2)),
      clearError: true,
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
      state = state.copyWith(isLoading: false, isMutating: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isMutating: false,
        error: e.toString(),
      );
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
    if (quantity < 1) {
      throw ApiException('Quantity must be at least 1');
    }

    final snapshot = state;
    _optimisticSeq += 1;
    final nextItems = [
      ...state.items,
      CartLine(
        cartItemId: 'local-$_optimisticSeq',
        product: product,
        quantity: quantity,
        lineTotal: product.price * quantity,
      ),
    ];

    state = _retotal(nextItems).copyWith(isMutating: true);

    try {
      final cart = await ref.read(cartRepositoryProvider).add(
            itemId: product.id,
            lockerId: product.lockerId.isNotEmpty ? product.lockerId : null,
            quantity: quantity,
          );
      _apply(cart);
    } catch (e) {
      state = snapshot.copyWith(
        isMutating: false,
        error: e is ApiException ? e.message : e.toString(),
      );
      rethrow;
    }
  }

  Future<void> setQuantity(String cartItemId, int quantity) async {
    if (cartItemId.isEmpty || cartItemId.startsWith('local-')) {
      throw ApiException('Cart item is still syncing — try again');
    }
    if (quantity < 1) {
      await remove(cartItemId);
      return;
    }

    final index = state.items.indexWhere((e) => e.cartItemId == cartItemId);
    if (index < 0) {
      throw ApiException('Cart item not found');
    }

    final snapshot = state;
    final line = state.items[index];
    final updated = line.copyWith(
      quantity: quantity,
      lineTotal: line.product.price * quantity,
    );
    final nextItems = [...state.items];
    nextItems[index] = updated;
    state = _retotal(nextItems).copyWith(isMutating: true);

    try {
      final cart = await ref.read(cartRepositoryProvider).update(
            cartItemId: cartItemId,
            quantity: quantity,
          );
      _apply(cart);
    } catch (e) {
      state = snapshot.copyWith(
        isMutating: false,
        error: e is ApiException ? e.message : e.toString(),
      );
      rethrow;
    }
  }

  Future<void> remove(String cartItemId) async {
    final id = cartItemId.trim();
    if (id.isEmpty || id == 'null' || id == 'undefined') {
      throw ApiException('Invalid cart item id');
    }
    if (id.startsWith('local-')) {
      final index = state.items.indexWhere((e) => e.cartItemId == id);
      if (index < 0) return;
      final next = [...state.items]..removeAt(index);
      state = _retotal(next);
      return;
    }

    final index = state.items.indexWhere((e) => e.cartItemId == id);
    if (index < 0) {
      throw ApiException('Cart item not found');
    }

    final snapshot = state;
    final next = [...state.items]..removeAt(index);
    state = _retotal(next).copyWith(isMutating: true);

    try {
      final cart = await ref.read(cartRepositoryProvider).remove(id);
      _apply(cart);
    } catch (e) {
      state = snapshot.copyWith(
        isMutating: false,
        error: e is ApiException ? e.message : e.toString(),
      );
      rethrow;
    }
  }

  Future<void> clearCart() async {
    if (state.items.isEmpty) return;
    final snapshot = state;
    state = const CartState(isMutating: true);

    try {
      final cart = await ref.read(cartRepositoryProvider).clear();
      _apply(cart);
    } catch (e) {
      state = snapshot.copyWith(
        isMutating: false,
        error: e is ApiException ? e.message : e.toString(),
      );
      rethrow;
    }
  }
}

final cartViewModelProvider =
    NotifierProvider<CartViewModel, CartState>(CartViewModel.new);
