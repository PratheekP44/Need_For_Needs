import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable UI state placeholder for Orders.
class OrdersState {
  const OrdersState({this.message = 'Orders placeholder'});

  final String message;

  OrdersState copyWith({String? message}) {
    return OrdersState(message: message ?? this.message);
  }
}

/// Riverpod ViewModel skeleton for Orders (MVVM).
class OrdersViewModel extends Notifier<OrdersState> {
  @override
  OrdersState build() => const OrdersState();
}

final ordersViewModelProvider =
    NotifierProvider<OrdersViewModel, OrdersState>(OrdersViewModel.new);
