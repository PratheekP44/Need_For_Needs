import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable UI state placeholder for Admin.
class AdminState {
  const AdminState({this.message = 'Admin placeholder'});

  final String message;

  AdminState copyWith({String? message}) {
    return AdminState(message: message ?? this.message);
  }
}

/// Riverpod ViewModel skeleton for Admin (MVVM).
class AdminViewModel extends Notifier<AdminState> {
  @override
  AdminState build() => const AdminState();
}

final adminViewModelProvider =
    NotifierProvider<AdminViewModel, AdminState>(AdminViewModel.new);
