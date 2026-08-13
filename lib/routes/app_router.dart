import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api/auth_debug.dart';
import '../core/constants/route_constants.dart';
import '../core/providers/core_providers.dart';
import '../core/widgets/main_shell.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/admin/screens/admin_items_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/ble_debug/screens/ble_debug_screen.dart';
import '../features/cart/screens/cart_screen.dart';
import '../features/developer_dashboard/screens/developer_dashboard_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/inventory/screens/product_details_screen.dart';
import '../features/locker/screens/locker_details_screen.dart';
import '../features/orders/screens/order_details_screen.dart';
import '../features/orders/screens/orders_screen.dart';
import '../features/payment/screens/payment_success_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import 'route_names.dart';

/// Stable GoRouter instance. Auth changes notify via [refreshListenable] only —
/// never recreate the router (that resets to splash and causes login loops).
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: RouteConstants.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authSessionProvider);
      final path = state.uri.path;
      final holdSplash = ref.read(splashHoldProvider);

      String? decide() {
        // Wait for startup restore before any auth decision.
        // Allow developer dashboard early (splash 5× long-press may race auth init).
        if (!auth.isInitialized) {
          if (path == RouteConstants.splash) return null;
          if (path == RouteConstants.developerDashboard) return null;
          if (path == RouteConstants.bleDebug) return null;
          return RouteConstants.splash;
        }

        final isSplash = path == RouteConstants.splash;
        final isLogin = path == RouteConstants.login;
        final isSignup = path == RouteConstants.signup;
        final isAdminLogin = path == RouteConstants.adminLogin;
        final isAuthEntry = isLogin || isSignup || isAdminLogin;
        final isDeveloper = path == RouteConstants.developerDashboard ||
            path == RouteConstants.bleDebug;
        final isAdminRoute =
            path.startsWith('/admin') && path != RouteConstants.adminLogin;

        // Hold splash open so 5× logo long-press can unlock the developer dashboard.
        if (isSplash && holdSplash) {
          return null;
        }

        if (!auth.isAuthenticated) {
          if (isAuthEntry || isDeveloper) return null;
          if (isSplash) return RouteConstants.login;
          return RouteConstants.login;
        }

        // Authenticated: never send back to login/signup/splash (after hold).
        if (isSplash) {
          return auth.isAdmin
              ? RouteConstants.adminDashboard
              : RouteConstants.home;
        }
        if (isLogin || isSignup) {
          return auth.isAdmin
              ? RouteConstants.adminDashboard
              : RouteConstants.locationPermission;
        }
        if (isAdminLogin) {
          return auth.isAdmin
              ? RouteConstants.adminDashboard
              : RouteConstants.home;
        }
        if (isAdminRoute && !auth.isAdmin) {
          return RouteConstants.adminLogin;
        }
        // Developer dashboard is reachable while signed in (Settings → developer).
        if (isDeveloper) return null;
        return null;
      }

      final target = decide();
      authLog(
        'GoRouter redirect path=$path '
        'initialized=${auth.isInitialized} '
        'authenticated=${auth.isAuthenticated} '
        'holdSplash=$holdSplash '
        'loading=${auth.isLoading} '
        'admin=${auth.isAdmin} '
        '→ ${target ?? 'null (stay)'}',
      );
      return target;
    },
    routes: [
      GoRoute(
        path: RouteConstants.splash,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteConstants.login,
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteConstants.signup,
        name: RouteNames.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: RouteConstants.locationPermission,
        name: RouteNames.locationPermission,
        builder: (context, state) => const LocationPermissionScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteConstants.home,
                name: RouteNames.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteConstants.orders,
                name: RouteNames.orders,
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteConstants.profile,
                name: RouteNames.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RouteConstants.lockerDetails,
        name: RouteNames.lockerDetails,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return LockerDetailsScreen(lockerId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.productDetails,
        name: RouteNames.productDetails,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ProductDetailsScreen(productId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.cart,
        name: RouteNames.cart,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: RouteConstants.checkout,
        name: RouteNames.checkout,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: RouteConstants.paymentSuccess,
        name: RouteNames.paymentSuccess,
        builder: (context, state) => const PaymentSuccessScreen(),
      ),
      GoRoute(
        path: RouteConstants.orderDetails,
        name: RouteNames.orderDetails,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderDetailsScreen(orderId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.collectItem,
        name: RouteNames.collectItem,
        builder: (context, state) {
          final orderId = state.uri.queryParameters['orderId'];
          return CollectItemScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: RouteConstants.settings,
        name: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RouteConstants.help,
        name: RouteNames.help,
        builder: (context, state) => const HelpScreen(),
      ),
      GoRoute(
        path: RouteConstants.developerDashboard,
        name: RouteNames.developerDashboard,
        builder: (context, state) => const DeveloperDashboardScreen(),
      ),
      GoRoute(
        path: RouteConstants.bleDebug,
        name: RouteNames.bleDebug,
        builder: (context, state) => const BleDebugScreen(),
      ),
      GoRoute(
        path: RouteConstants.adminLogin,
        name: RouteNames.adminLogin,
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: RouteConstants.adminDashboard,
        name: RouteNames.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: RouteConstants.adminLockers,
        name: RouteNames.adminLockers,
        builder: (context, state) => const AdminLockerManagementScreen(),
      ),
      GoRoute(
        path: RouteConstants.adminInventory,
        name: RouteNames.adminInventory,
        builder: (context, state) => const AdminInventoryScreen(),
      ),
      GoRoute(
        path: RouteConstants.adminInventoryAdd,
        name: RouteNames.adminInventoryAdd,
        builder: (context, state) => const AdminAddItemScreen(),
      ),
      GoRoute(
        path: RouteConstants.adminInventoryEdit,
        name: RouteNames.adminInventoryEdit,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return AdminEditItemScreen(itemId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.adminInventoryAssign,
        name: RouteNames.adminInventoryAssign,
        builder: (context, state) {
          final itemId = state.uri.queryParameters['itemId'];
          return AdminAssignStockScreen(initialItemId: itemId);
        },
      ),
      GoRoute(
        path: RouteConstants.adminOrders,
        name: RouteNames.adminOrders,
        builder: (context, state) => const AdminOrdersScreen(),
      ),
      GoRoute(
        path: RouteConstants.adminItems,
        name: RouteNames.adminItems,
        builder: (context, state) => const AdminItemsScreen(),
      ),
      GoRoute(
        path: RouteConstants.adminItemsAdd,
        name: RouteNames.adminItemsAdd,
        builder: (context, state) => const AdminAddItemScreen(),
      ),
      GoRoute(
        path: RouteConstants.adminItemsEdit,
        name: RouteNames.adminItemsEdit,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return AdminEditItemScreen(itemId: id);
        },
      ),
    ],
  );
});

/// Notifies GoRouter when auth session or splash hold changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this.ref) {
    _authSub = ref.listen<AuthSessionState>(authSessionProvider, (prev, next) {
      authLog(
        'AuthRefresh notify '
        'prev(auth=${prev?.isAuthenticated}, init=${prev?.isInitialized}) '
        '→ next(auth=${next.isAuthenticated}, init=${next.isInitialized})',
      );
      notifyListeners();
    });
    _splashSub = ref.listen<bool>(splashHoldProvider, (prev, next) {
      authLog('SplashHold notify hold=$next');
      notifyListeners();
    });
  }

  final Ref ref;
  late final ProviderSubscription<AuthSessionState> _authSub;
  late final ProviderSubscription<bool> _splashSub;

  @override
  void dispose() {
    _authSub.close();
    _splashSub.close();
    super.dispose();
  }
}
