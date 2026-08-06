/// Production UI display models (populated from backend APIs / MongoDB).
class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    this.icon = 'inventory_2',
    this.itemCount = 0,
  });

  final String id;
  final String name;
  final String icon;
  final int itemCount;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.categoryId,
    required this.lockerId,
    required this.stockId,
    this.boxId = '',
    this.lockerName = '',
    this.boxNumber,
    this.availability = 'unavailable',
    this.imageUrl = '',
    this.description = '',
  });

  final String id;
  final String name;
  final double price;
  final int stock;
  final String categoryId;
  final String lockerId;
  final String stockId;
  final String boxId;
  final String lockerName;
  final int? boxNumber;
  final String availability;
  final String imageUrl;
  final String description;

  bool get hasCartMapping =>
      id.isNotEmpty &&
      id != 'null' &&
      stock > 0;

  bool get isAvailable =>
      availability == 'available' && stock > 0 && hasCartMapping;
}

class Locker {
  const Locker({
    required this.id,
    required this.name,
    required this.distanceMeters,
    required this.availableItems,
    required this.status,
    required this.openBoxes,
    required this.totalBoxes,
    this.latitude,
    this.longitude,
    this.lockerCode = '',
  });

  final String id;
  final String name;
  final int distanceMeters;
  final int availableItems;
  final String status;
  final int openBoxes;
  final int totalBoxes;
  final double? latitude;
  final double? longitude;
  final String lockerCode;

  Locker copyWith({
    int? distanceMeters,
    int? availableItems,
    String? status,
    int? openBoxes,
  }) {
    return Locker(
      id: id,
      name: name,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      availableItems: availableItems ?? this.availableItems,
      status: status ?? this.status,
      openBoxes: openBoxes ?? this.openBoxes,
      totalBoxes: totalBoxes,
      latitude: latitude,
      longitude: longitude,
      lockerCode: lockerCode,
    );
  }
}

class CartLine {
  const CartLine({
    required this.cartItemId,
    required this.product,
    required this.quantity,
    this.lineTotal,
  });

  final String cartItemId;
  final Product product;
  final int quantity;
  final double? lineTotal;

  double get computedLineTotal => lineTotal ?? product.price * quantity;
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.lockerName,
    required this.lockerNumber,
    required this.status,
    required this.total,
    required this.placedAt,
    required this.boxes,
    required this.itemCount,
    this.paymentStatus = '',
    this.collectionToken = '',
    this.itemImages = const [],
    this.itemNames = const [],
  });

  final String id;
  final String lockerName;
  final String lockerNumber;
  final String status;
  final double total;
  final String placedAt;
  final List<String> boxes;
  final int itemCount;
  final String paymentStatus;
  final String collectionToken;
  final List<String> itemImages;
  final List<String> itemNames;
}

class AppUser {
  const AppUser({
    required this.name,
    required this.email,
    required this.savedLocations,
    this.phone = '',
    this.role = 'user',
    this.joinedDate = '',
    this.orderCount = 0,
    this.totalPurchases = 0,
  });

  final String name;
  final String email;
  final String phone;
  final List<String> savedLocations;
  final String role;
  final String joinedDate;
  final int orderCount;
  final double totalPurchases;

  bool get isAdmin => role == 'admin';
}

class AdminStats {
  const AdminStats({
    required this.totalLockers,
    required this.availableLockers,
    required this.ordersToday,
    required this.revenueToday,
    required this.inventoryStatus,
    this.totalUsers = 0,
    this.totalAdmins = 0,
    this.totalItems = 0,
    this.lowStockCount = 0,
    this.outOfStockCount = 0,
    this.emptyBoxes = 0,
    this.occupiedBoxes = 0,
    this.lockersOnline = 0,
    this.lockersOffline = 0,
  });

  final int totalLockers;
  final int availableLockers;
  final int ordersToday;
  final double revenueToday;
  final String inventoryStatus;
  final int totalUsers;
  final int totalAdmins;
  final int totalItems;
  final int lowStockCount;
  final int outOfStockCount;
  final int emptyBoxes;
  final int occupiedBoxes;
  final int lockersOnline;
  final int lockersOffline;
}

class InventoryRow {
  const InventoryRow({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.assignedLocker,
    this.stockId = '',
    this.boxId = '',
    this.boxNumber,
    this.imageUrl = '',
    this.itemId = '',
  });

  final String id;
  final String name;
  final double price;
  final int quantity;
  final String assignedLocker;
  final String stockId;
  final String boxId;
  final int? boxNumber;
  final String imageUrl;
  final String itemId;
}

class HomeCatalog {
  const HomeCatalog({
    this.popular = const [],
    this.newest = const [],
    this.recommended = const [],
    this.recent = const [],
    this.categories = const [],
  });

  final List<Product> popular;
  final List<Product> newest;
  final List<Product> recommended;
  final List<Product> recent;
  final List<ProductCategory> categories;
}
