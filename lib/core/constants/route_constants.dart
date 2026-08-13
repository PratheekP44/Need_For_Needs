/// Route path constants used by GoRouter.
class RouteConstants {
  const RouteConstants._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String locationPermission = '/location-permission';

  static const String home = '/home';
  static const String orders = '/orders';
  static const String orderDetails = '/orders/:id';
  static const String profile = '/profile';

  static const String lockerDetails = '/locker/:id';
  static const String productDetails = '/product/:id';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String paymentSuccess = '/payment-success';
  static const String collectItem = '/collect-item';
  static const String settings = '/settings';
  static const String help = '/help';
  /// Hidden engineering entry (splash / settings) — not Admin Portal.
  static const String developerDashboard = '/developer-dashboard';
  static const String bleDebug = '/ble-debug';

  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminLockers = '/admin/lockers';
  static const String adminInventory = '/admin/inventory';
  static const String adminInventoryAdd = '/admin/inventory/add';
  static const String adminInventoryEdit = '/admin/inventory/edit/:id';
  static const String adminInventoryAssign = '/admin/inventory/assign';
  static const String adminOrders = '/admin/orders';
  static const String adminItems = '/admin/items';
  static const String adminItemsAdd = '/admin/items/add';
  static const String adminItemsEdit = '/admin/items/edit/:id';
}
