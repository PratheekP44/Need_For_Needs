import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable UI state placeholder for Locker.
class LockerState {
  const LockerState({this.message = 'Locker placeholder'});

  final String message;

  LockerState copyWith({String? message}) {
    return LockerState(message: message ?? this.message);
  }
}

/// Riverpod ViewModel skeleton for Locker (MVVM).
class LockerViewModel extends Notifier<LockerState> {
  @override
  LockerState build() => const LockerState();
}

final lockerViewModelProvider =
    NotifierProvider<LockerViewModel, LockerState>(LockerViewModel.new);
