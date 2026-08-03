import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable UI state placeholder for Home.
class HomeState {
  const HomeState({this.message = 'Home placeholder'});

  final String message;

  HomeState copyWith({String? message}) {
    return HomeState(message: message ?? this.message);
  }
}

/// Riverpod ViewModel skeleton for Home (MVVM).
class HomeViewModel extends Notifier<HomeState> {
  @override
  HomeState build() => const HomeState();
}

final homeViewModelProvider =
    NotifierProvider<HomeViewModel, HomeState>(HomeViewModel.new);
