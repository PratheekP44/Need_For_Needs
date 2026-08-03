import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/route_constants.dart';
import '../core/widgets/main_shell.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/cart/screens/cart_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/inventory/screens/product_details_screen.dart';
import '../features/locker/screens/locker_details_screen.dart';
import '../features/orders/screens/orders_screen.dart';
import '../features/payment/screens/payment_success_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteConstants.splash,
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
          final id = state.pathParameters['id'] ?? 'l1';
          return LockerDetailsScreen(lockerId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.productDetails,
        name: RouteNames.productDetails,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? 'p1';
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
        path: RouteConstants.collectItem,
        name: RouteNames.collectItem,
        builder: (context, state) => const CollectItemScreen(),
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
          final id = state.pathParameters['id'] ?? 'p1';
          return AdminEditItemScreen(itemId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.adminOrders,
        name: RouteNames.adminOrders,
        builder: (context, state) => const AdminOrdersScreen(),
      ),
    ],
  );
});
