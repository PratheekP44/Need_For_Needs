import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/auth_debug.dart';
import '../api/repositories.dart';
import '../api/unlock_payload_repository.dart';
import '../ble/models/unlock_payload.dart';
import '../ble/unlock/unlock_payload_service.dart';
import '../config/env_config.dart';
import '../data/models.dart';
import '../location/location_service.dart';
import '../payment/checkout_payment_service.dart';
import '../services/app_service.dart';

final envConfigProvider = Provider<EnvConfig>((ref) {
  return EnvConfig.resolve();
});

final appServiceProvider = Provider<AppService>((ref) {
  return const AppService();
});

final sessionStoreProvider = Provider<SessionStore>((ref) {
  return SessionStore();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    config: ref.watch(envConfigProvider),
    session: ref.watch(sessionStoreProvider),
  );
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  );
});

final lockerRepositoryProvider = Provider<LockerRepository>((ref) {
  return LockerRepository(
    ref.watch(apiClientProvider),
    ref.watch(locationServiceProvider),
  );
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiClientProvider));
});

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiClientProvider));
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(apiClientProvider));
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(apiClientProvider));
});

final unlockPayloadRepositoryProvider = Provider<UnlockPayloadRepository>((ref) {
  return UnlockPayloadRepository(ref.watch(apiClientProvider));
});

final unlockPayloadServiceProvider = Provider<UnlockPayloadService>((ref) {
  return UnlockPayloadService(ref.watch(unlockPayloadRepositoryProvider));
});

final checkoutPaymentServiceProvider = Provider<CheckoutPaymentService>((ref) {
  return CheckoutPaymentService(
    orders: ref.watch(orderRepositoryProvider),
    payments: ref.watch(paymentRepositoryProvider),
  );
});

/// Last successful payment (for success / collect screens).
class LastPaymentNotifier extends Notifier<OrderPaymentResult?> {
  @override
  OrderPaymentResult? build() => null;

  // ignore: use_setters_to_change_properties
  void setResult(OrderPaymentResult? value) => state = value;
}

final lastPaymentResultProvider =
    NotifierProvider<LastPaymentNotifier, OrderPaymentResult?>(
  LastPaymentNotifier.new,
);

/// Stored backend unlock payload for the active Collect session.
class UnlockPayloadNotifier extends Notifier<UnlockPayload?> {
  @override
  UnlockPayload? build() => null;

  // ignore: use_setters_to_change_properties
  void setPayload(UnlockPayload? value) => state = value;

  void clear() => state = null;
}

final lastUnlockPayloadProvider =
    NotifierProvider<UnlockPayloadNotifier, UnlockPayload?>(
  UnlockPayloadNotifier.new,
);

class AuthSessionState {
  const AuthSessionState({
    this.user,
    this.isLoading = true,
    this.isInitialized = false,
    this.error,
  });

  final AppUser? user;
  final bool isLoading;
  /// True after the first startup [AuthSessionNotifier.restore] finishes.
  final bool isInitialized;
  final String? error;

  bool get isAuthenticated => user != null;
  bool get isAdmin => user?.isAdmin == true;

  AuthSessionState copyWith({
    AppUser? user,
    bool? isLoading,
    bool? isInitialized,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthSessionState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthSessionNotifier extends Notifier<AuthSessionState> {
  @override
  AuthSessionState build() {
    Future.microtask(restore);
    return const AuthSessionState();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> restore() async {
    authLog('AuthState restore start');
    state = state.copyWith(isLoading: true, clearError: true);
    final user = await _repo.restore();
    state = AuthSessionState(
      user: user,
      isLoading: false,
      isInitialized: true,
    );
    authLog(
      'AuthState restore done authenticated=${user != null} '
      'name=${user?.name} role=${user?.role}',
    );
  }

  Future<AppUser> login(String email, String password) async {
    authLog('AuthState login start');
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.login(email: email, password: password);
      state = AuthSessionState(
        user: user,
        isLoading: false,
        isInitialized: true,
      );
      authLog('AuthState login success user=${user.email} role=${user.role}');
      return user;
    } catch (e) {
      authLog('AuthState login failed: $e');
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        error: e.toString(),
        clearUser: true,
      );
      rethrow;
    }
  }

  Future<AppUser> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    authLog('AuthState signup start');
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.signup(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
      state = AuthSessionState(
        user: user,
        isLoading: false,
        isInitialized: true,
      );
      authLog('AuthState signup success user=${user.email}');
      return user;
    } catch (e) {
      authLog('AuthState signup failed: $e');
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        error: e.toString(),
        clearUser: true,
      );
      rethrow;
    }
  }

  Future<void> logout() async {
    authLog('AuthState logout');
    await _repo.logout();
    state = const AuthSessionState(isLoading: false, isInitialized: true);
    authLog('AuthState logout done — session cleared');
  }

  Future<void> refreshProfile() async {
    if (!await ref.read(sessionStoreProvider).hasSession) return;
    final user = await _repo.fetchProfile();
    state = AuthSessionState(
      user: user,
      isLoading: false,
      isInitialized: true,
    );
    authLog('AuthState profile refreshed user=${user.email}');
  }
}

final authSessionProvider =
    NotifierProvider<AuthSessionNotifier, AuthSessionState>(AuthSessionNotifier.new);

/// Keeps the splash route mounted until the splash timer finishes (or the
/// developer dashboard is unlocked via 5× logo long-press).
class SplashHoldNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void hold() => state = true;

  void release() => state = false;
}

final splashHoldProvider =
    NotifierProvider<SplashHoldNotifier, bool>(SplashHoldNotifier.new);
