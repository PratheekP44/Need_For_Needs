/// Fake placeholder data for UI skeleton. No networking.
class FakeCategory {
  const FakeCategory({required this.id, required this.name, required this.icon});
  final String id;
  final String name;
  final String icon;
}

class FakeProduct {
  const FakeProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.categoryId,
    required this.lockerId,
    this.description = 'Campus essential item ready for locker pickup.',
  });

  final String id;
  final String name;
  final double price;
  final int stock;
  final String categoryId;
  final String lockerId;
  final String description;
}

class FakeLocker {
  const FakeLocker({
    required this.id,
    required this.name,
    required this.distanceMeters,
    required this.availableItems,
    required this.status,
    required this.openBoxes,
    required this.totalBoxes,
  });

  final String id;
  final String name;
  final int distanceMeters;
  final int availableItems;
  final String status;
  final int openBoxes;
  final int totalBoxes;
}

class FakeCartItem {
  const FakeCartItem({
    required this.product,
    required this.quantity,
  });

  final FakeProduct product;
  final int quantity;

  double get lineTotal => product.price * quantity;
}

class FakeOrder {
  const FakeOrder({
    required this.id,
    required this.lockerName,
    required this.lockerNumber,
    required this.status,
    required this.total,
    required this.placedAt,
    required this.boxes,
    required this.itemCount,
  });

  final String id;
  final String lockerName;
  final String lockerNumber;
  final String status;
  final double total;
  final String placedAt;
  final List<String> boxes;
  final int itemCount;
}

class FakeUser {
  const FakeUser({
    required this.name,
    required this.email,
    required this.savedLocations,
  });

  final String name;
  final String email;
  final List<String> savedLocations;
}

class FakeAdminStats {
  const FakeAdminStats({
    required this.totalLockers,
    required this.availableLockers,
    required this.ordersToday,
    required this.revenueToday,
    required this.inventoryStatus,
  });

  final int totalLockers;
  final int availableLockers;
  final int ordersToday;
  final double revenueToday;
  final String inventoryStatus;
}

class FakeInventoryRow {
  const FakeInventoryRow({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.assignedLocker,
  });

  final String id;
  final String name;
  final double price;
  final int quantity;
  final String assignedLocker;
}

/// Central fake dataset for Campus Essentials UI.
class FakeData {
  const FakeData._();

  static const user = FakeUser(
    name: 'Aisha Rahman',
    email: 'aisha.rahman@campus.edu',
    savedLocations: [
      'North Quad Locker Hub',
      'Library Annex',
      'Engineering Block B',
    ],
  );

  static const categories = <FakeCategory>[
    FakeCategory(id: 'c1', name: 'Snacks', icon: 'cookie'),
    FakeCategory(id: 'c2', name: 'Drinks', icon: 'local_cafe'),
    FakeCategory(id: 'c3', name: 'Stationery', icon: 'edit'),
    FakeCategory(id: 'c4', name: 'Hygiene', icon: 'soap'),
    FakeCategory(id: 'c5', name: 'Tech', icon: 'headphones'),
  ];

  static const lockers = <FakeLocker>[
    FakeLocker(
      id: 'l1',
      name: 'North Quad Hub',
      distanceMeters: 120,
      availableItems: 24,
      status: 'Online',
      openBoxes: 3,
      totalBoxes: 12,
    ),
    FakeLocker(
      id: 'l2',
      name: 'Library Annex',
      distanceMeters: 340,
      availableItems: 18,
      status: 'Online',
      openBoxes: 1,
      totalBoxes: 10,
    ),
    FakeLocker(
      id: 'l3',
      name: 'Engineering B',
      distanceMeters: 510,
      availableItems: 9,
      status: 'Maintenance',
      openBoxes: 0,
      totalBoxes: 8,
    ),
    FakeLocker(
      id: 'l4',
      name: 'Sports Complex',
      distanceMeters: 780,
      availableItems: 15,
      status: 'Online',
      openBoxes: 2,
      totalBoxes: 10,
    ),
  ];

  static const products = <FakeProduct>[
    FakeProduct(
      id: 'p1',
      name: 'Protein Bar',
      price: 2.49,
      stock: 14,
      categoryId: 'c1',
      lockerId: 'l1',
    ),
    FakeProduct(
      id: 'p2',
      name: 'Cold Brew Can',
      price: 3.25,
      stock: 8,
      categoryId: 'c2',
      lockerId: 'l1',
    ),
    FakeProduct(
      id: 'p3',
      name: 'Gel Pen Pack',
      price: 4.99,
      stock: 21,
      categoryId: 'c3',
      lockerId: 'l2',
    ),
    FakeProduct(
      id: 'p4',
      name: 'Hand Sanitizer',
      price: 1.99,
      stock: 30,
      categoryId: 'c4',
      lockerId: 'l2',
    ),
    FakeProduct(
      id: 'p5',
      name: 'USB-C Cable',
      price: 7.50,
      stock: 6,
      categoryId: 'c5',
      lockerId: 'l1',
    ),
    FakeProduct(
      id: 'p6',
      name: 'Trail Mix',
      price: 2.99,
      stock: 11,
      categoryId: 'c1',
      lockerId: 'l4',
    ),
    FakeProduct(
      id: 'p7',
      name: 'Sparkling Water',
      price: 1.75,
      stock: 16,
      categoryId: 'c2',
      lockerId: 'l4',
    ),
    FakeProduct(
      id: 'p8',
      name: 'Sticky Notes',
      price: 2.20,
      stock: 25,
      categoryId: 'c3',
      lockerId: 'l1',
    ),
  ];

  static final cartItems = <FakeCartItem>[
    FakeCartItem(product: products[0], quantity: 2),
    FakeCartItem(product: products[1], quantity: 1),
    FakeCartItem(product: products[4], quantity: 1),
  ];

  static final recentProducts = <FakeProduct>[
    products[2],
    products[3],
    products[5],
  ];

  static final popularProducts = <FakeProduct>[
    products[0],
    products[1],
    products[4],
    products[6],
  ];

  static const orders = <FakeOrder>[
    FakeOrder(
      id: 'ORD-10482',
      lockerName: 'North Quad Hub',
      lockerNumber: 'A-04',
      status: 'Ready to collect',
      total: 15.73,
      placedAt: 'Today - 2:14 PM',
      boxes: ['B2', 'B5'],
      itemCount: 3,
    ),
    FakeOrder(
      id: 'ORD-10461',
      lockerName: 'Library Annex',
      lockerNumber: 'C-02',
      status: 'Collected',
      total: 8.40,
      placedAt: 'Yesterday - 6:02 PM',
      boxes: ['A1'],
      itemCount: 2,
    ),
    FakeOrder(
      id: 'ORD-10420',
      lockerName: 'Sports Complex',
      lockerNumber: 'D-07',
      status: 'Collected',
      total: 12.15,
      placedAt: 'Mon - 11:30 AM',
      boxes: ['C3', 'C4'],
      itemCount: 4,
    ),
  ];

  static const adminStats = FakeAdminStats(
    totalLockers: 12,
    availableLockers: 9,
    ordersToday: 47,
    revenueToday: 862.40,
    inventoryStatus: 'Healthy',
  );

  static const inventoryRows = <FakeInventoryRow>[
    FakeInventoryRow(
      id: 'p1',
      name: 'Protein Bar',
      price: 2.49,
      quantity: 14,
      assignedLocker: 'North Quad Hub',
    ),
    FakeInventoryRow(
      id: 'p2',
      name: 'Cold Brew Can',
      price: 3.25,
      quantity: 8,
      assignedLocker: 'North Quad Hub',
    ),
    FakeInventoryRow(
      id: 'p3',
      name: 'Gel Pen Pack',
      price: 4.99,
      quantity: 21,
      assignedLocker: 'Library Annex',
    ),
    FakeInventoryRow(
      id: 'p4',
      name: 'Hand Sanitizer',
      price: 1.99,
      quantity: 30,
      assignedLocker: 'Library Annex',
    ),
    FakeInventoryRow(
      id: 'p5',
      name: 'USB-C Cable',
      price: 7.50,
      quantity: 6,
      assignedLocker: 'North Quad Hub',
    ),
  ];

  static FakeLocker lockerById(String id) =>
      lockers.firstWhere((l) => l.id == id, orElse: () => lockers.first);

  static FakeProduct productById(String id) =>
      products.firstWhere((p) => p.id == id, orElse: () => products.first);

  static List<FakeProduct> productsForLocker(String lockerId) =>
      products.where((p) => p.lockerId == lockerId).toList();

  static double get cartSubtotal =>
      cartItems.fold(0, (sum, item) => sum + item.lineTotal);
}
