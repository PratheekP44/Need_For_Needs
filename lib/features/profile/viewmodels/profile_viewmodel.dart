import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable UI state placeholder for Profile.
class ProfileState {
  const ProfileState({this.message = 'Profile placeholder'});

  final String message;

  ProfileState copyWith({String? message}) {
    return ProfileState(message: message ?? this.message);
  }
}

/// Riverpod ViewModel skeleton for Profile (MVVM).
class ProfileViewModel extends Notifier<ProfileState> {
  @override
  ProfileState build() => const ProfileState();
}

final profileViewModelProvider =
    NotifierProvider<ProfileViewModel, ProfileState>(ProfileViewModel.new);
