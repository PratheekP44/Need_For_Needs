import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable UI state placeholder for Cart.
class CartState {
  const CartState({this.message = 'Cart placeholder'});

  final String message;

  CartState copyWith({String? message}) {
    return CartState(message: message ?? this.message);
  }
}

/// Riverpod ViewModel skeleton for Cart (MVVM).
class CartViewModel extends Notifier<CartState> {
  @override
  CartState build() => const CartState();
}

final cartViewModelProvider =
    NotifierProvider<CartViewModel, CartState>(CartViewModel.new);
