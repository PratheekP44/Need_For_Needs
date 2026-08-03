import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable UI state placeholder for Auth.
class AuthState {
  const AuthState({this.message = 'Auth placeholder'});

  final String message;

  AuthState copyWith({String? message}) {
    return AuthState(message: message ?? this.message);
  }
}

/// Riverpod ViewModel skeleton for Auth (MVVM).
class AuthViewModel extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();
}

final authViewModelProvider =
    NotifierProvider<AuthViewModel, AuthState>(AuthViewModel.new);
