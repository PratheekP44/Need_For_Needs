import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable UI state placeholder for Inventory.
class InventoryState {
  const InventoryState({this.message = 'Inventory placeholder'});

  final String message;

  InventoryState copyWith({String? message}) {
    return InventoryState(message: message ?? this.message);
  }
}

/// Riverpod ViewModel skeleton for Inventory (MVVM).
class InventoryViewModel extends Notifier<InventoryState> {
  @override
  InventoryState build() => const InventoryState();
}

final inventoryViewModelProvider =
    NotifierProvider<InventoryViewModel, InventoryState>(InventoryViewModel.new);
