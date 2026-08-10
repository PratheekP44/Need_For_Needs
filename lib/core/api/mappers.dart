import '../data/models.dart';
import '../location/location_service.dart';

String _statusLabel(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'ONLINE':
    case 'ACTIVE':
      return 'Online';
    case 'OFFLINE':
      return 'Offline';
    case 'MAINTENANCE':
      return 'Maintenance';
    default:
      return raw?.isNotEmpty == true ? raw! : 'Unknown';
  }
}

String _orderStatusLabel(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'READY_FOR_COLLECTION':
      return 'Ready to collect';
    case 'WAITING_PAYMENT':
    case 'CREATED':
      return 'Awaiting payment';
    case 'PAYMENT_SUCCESS':
      return 'Paid';
    case 'COLLECTED':
      return 'Collected';
    case 'CANCELLED':
      return 'Cancelled';
    case 'EXPIRED':
      return 'Expired';
    default:
      return raw?.replaceAll('_', ' ') ?? 'Unknown';
  }
}

Locker mapLocker(
  Map<String, dynamic> json, {
  int? distanceMeters,
  int availableItems = 0,
}) {
  final boxes = asList(json['boxes']);
  final openBoxes = boxes.where((b) {
    final m = asMap(b);
    return m['isEmpty'] == true ||
        (m['status']?.toString().toUpperCase() == 'EMPTY');
  }).length;

  return Locker(
    id: asString(json['id']) ?? asString(json['lockerId']) ?? '',
    name: asString(json['lockerName']) ?? 'Locker',
    distanceMeters: distanceMeters ?? asInt(json['distanceInMeters'], 0),
    availableItems: availableItems > 0
        ? availableItems
        : asInt(json['availableItems']),
    status: _statusLabel(asString(json['status'])),
    openBoxes: asInt(json['emptyBoxes'], openBoxes),
    totalBoxes: asInt(json['totalBoxes']),
    latitude: json['latitude'] is num ? (json['latitude'] as num).toDouble() : null,
    longitude: json['longitude'] is num ? (json['longitude'] as num).toDouble() : null,
    lockerCode: asString(json['lockerId']) ?? '',
    terminalNumber: json['terminalNumber'] == null
        ? null
        : asInt(json['terminalNumber']),
  );
}

Product mapStockToProduct(Map<String, dynamic> stock) {
  final item = stock['item'] is Map ? asMap(stock['item']) : <String, dynamic>{};
  final locker = stock['locker'] is Map ? asMap(stock['locker']) : <String, dynamic>{};
  final box = stock['box'] is Map ? asMap(stock['box']) : <String, dynamic>{};
  final category = asString(item['category']) ??
      asString(stock['category']) ??
      'General';
  final stockKey = asString(stock['stockId']) ?? '';

  final lockerId = asString(stock['lockerId']) ??
      asString(locker['id']) ??
      asString(locker['lockerId']) ??
      '';
  final boxId =
      asString(stock['boxId']) ?? asString(box['id']) ?? asString(box['boxId']) ?? '';
  final boxNumberRaw = stock['boxNumber'] ?? box['boxNumber'];
  // Aggregated catalog: availableQuantity = count of sellable stock rows.
  final qty = asInt(
    stock['availableQuantity'],
    asInt(stock['quantity'], asInt(stock['currentQuantity'])),
  );

  // Catalog product id is the Item id when API returns grouped products.
  final productId = asString(stock['id']) ??
      asString(item['id']) ??
      asString(stock['itemId']) ??
      stockKey;

  return Product(
    id: productId,
    stockId: stockKey,
    name: asString(item['name']) ?? asString(stock['name']) ?? 'Item',
    price: asDouble(item['sellingPrice'], asDouble(stock['price'])),
    stock: qty,
    categoryId: category,
    lockerId: lockerId,
    boxId: boxId,
    lockerName: asString(stock['lockerName']) ??
        asString(locker['lockerName']) ??
        '',
    boxNumber: boxNumberRaw is num
        ? boxNumberRaw.toInt()
        : int.tryParse('$boxNumberRaw'),
    availability: asString(stock['availability']) ??
        (qty > 0 ? 'available' : 'unavailable'),
    imageUrl: asString(item['imageUrl']) ?? asString(stock['imageUrl']) ?? '',
    description:
        asString(item['description']) ?? asString(stock['description']) ?? '',
  );
}

InventoryRow mapStockToInventory(Map<String, dynamic> stock) {
  final item = stock['item'] is Map ? asMap(stock['item']) : <String, dynamic>{};
  final locker = stock['locker'] is Map ? asMap(stock['locker']) : <String, dynamic>{};
  final box = stock['box'] is Map ? asMap(stock['box']) : <String, dynamic>{};
  final boxNumberRaw = stock['boxNumber'] ?? box['boxNumber'];
  final qty = asInt(stock['quantity'], asInt(stock['currentQuantity']));
  final isEmpty = stock['isEmpty'] == true || qty <= 0;
  return InventoryRow(
    id: asString(stock['stockId']) ??
        asString(stock['id']) ??
        asString(stock['boxId']) ??
        '',
    stockId: asString(stock['stockId']) ?? asString(stock['stockCode']) ?? '',
    name: asString(item['name']) ??
        asString(stock['itemName']) ??
        (isEmpty ? 'Empty Box' : 'Item'),
    price: asDouble(item['sellingPrice'], asDouble(stock['price'])),
    quantity: isEmpty ? 0 : (qty > 0 ? 1 : 0),
    assignedLocker: asString(stock['lockerName']) ??
        asString(locker['lockerName']) ??
        asString(locker['lockerId']) ??
        '—',
    boxId: asString(stock['boxId']) ?? asString(box['id']) ?? '',
    boxNumber: boxNumberRaw is num ? boxNumberRaw.toInt() : int.tryParse('$boxNumberRaw'),
    imageUrl: asString(item['imageUrl']) ?? asString(stock['imageUrl']) ?? '',
    itemId: asString(item['id']) ?? asString(item['itemId']) ?? asString(stock['itemId']) ?? '',
    isEmpty: isEmpty,
    occupancy: asString(stock['occupancy']) ?? (isEmpty ? 'Empty' : 'Occupied'),
    lockerMongoId: asString(locker['id']) ?? asString(stock['lockerId']) ?? '',
  );
}

InventoryRow mapPhysicalBoxRow(Map<String, dynamic> json) {
  final locker = json['locker'] is Map ? asMap(json['locker']) : <String, dynamic>{};
  final item = json['item'] is Map ? asMap(json['item']) : <String, dynamic>{};
  final isEmpty = json['isEmpty'] == true ||
      (asString(json['occupancy'])?.toLowerCase() == 'empty');
  final boxNumberRaw = json['boxNumber'];
  final stockId = asString(json['stockId']) ?? '';
  final boxId = asString(json['boxId']) ?? '';
  return InventoryRow(
    id: stockId.isNotEmpty ? stockId : 'box:$boxId',
    stockId: asString(json['stockCode']) ?? stockId,
    name: isEmpty
        ? 'Empty Box'
        : (asString(json['itemName']) ?? asString(item['name']) ?? 'Item'),
    price: asDouble(json['price'], asDouble(item['sellingPrice'])),
    quantity: isEmpty ? 0 : 1,
    assignedLocker: asString(locker['lockerName']) ??
        asString(locker['lockerId']) ??
        '—',
    boxId: boxId,
    boxNumber:
        boxNumberRaw is num ? boxNumberRaw.toInt() : int.tryParse('$boxNumberRaw'),
    imageUrl: asString(json['imageUrl']) ?? asString(item['imageUrl']) ?? '',
    itemId: asString(json['itemId']) ??
        asString(item['id']) ??
        asString(item['itemId']) ??
        '',
    isEmpty: isEmpty,
    occupancy: asString(json['occupancy']) ?? (isEmpty ? 'Empty' : 'Occupied'),
    lockerMongoId: asString(locker['id']) ?? '',
  );
}

PhysicalLockerInventory mapPhysicalLockerInventory(Map<String, dynamic> data) {
  final locker = data['locker'] is Map ? asMap(data['locker']) : <String, dynamic>{};
  final summary = data['summary'] is Map
      ? asMap(data['summary'])
      : <String, dynamic>{};
  final boxes = asList(data['boxes']).map((e) => mapPhysicalBoxRow(asMap(e))).toList();
  return PhysicalLockerInventory(
    lockerId: asString(locker['lockerId']) ?? '',
    lockerName: asString(locker['lockerName']) ?? 'Locker',
    lockerMongoId: asString(locker['id']) ?? '',
    summary: BoxInventorySummary(
      totalBoxes: asInt(summary['totalBoxes'], boxes.length),
      occupiedBoxes: asInt(summary['occupiedBoxes']),
      emptyBoxes: asInt(summary['emptyBoxes']),
    ),
    boxes: boxes,
  );
}

CartLine mapCartLine(Map<String, dynamic> line) {
  final item = line['item'] is Map ? asMap(line['item']) : <String, dynamic>{};
  final stock = line['stock'] is Map ? asMap(line['stock']) : <String, dynamic>{};
  final locker = line['locker'] is Map ? asMap(line['locker']) : <String, dynamic>{};
  final box = line['box'] is Map ? asMap(line['box']) : <String, dynamic>{};
  final stockKey = asString(stock['stockId']) ?? asString(stock['id']) ?? '';
  final product = Product(
    id: asString(item['id']) ?? stockKey,
    stockId: stockKey,
    name: asString(item['name']) ?? 'Item',
    price: asDouble(line['priceAtPurchase'], asDouble(item['sellingPrice'])),
    stock: asInt(stock['currentQuantity']),
    categoryId: (asString(item['category']) ?? 'general').toLowerCase(),
    lockerId: asString(locker['id']) ?? asString(locker['lockerId']) ?? '',
    boxId: asString(box['id']) ?? asString(box['boxId']) ?? '',
    lockerName: asString(locker['lockerName']) ?? '',
    boxNumber: box['boxNumber'] is num ? (box['boxNumber'] as num).toInt() : null,
    imageUrl: asString(item['imageUrl']) ?? '',
    description: asString(item['description']) ?? '',
  );
  return CartLine(
    cartItemId: asString(line['id']) ?? asString(line['_id']) ?? '',
    product: product,
    quantity: asInt(line['quantity'], 1),
    lineTotal: asDouble(line['subtotal'], product.price * asInt(line['quantity'], 1)),
  );
}

OrderSummary mapOrder(Map<String, dynamic> json) {
  final locker = json['locker'] is Map ? asMap(json['locker']) : <String, dynamic>{};
  final user = json['user'] is Map ? asMap(json['user']) : <String, dynamic>{};
  final items = asList(json['items']);
  final boxes = <String>{};
  final images = <String>[];
  final names = <String>[];
  var itemCount = 0;
  for (final raw in items) {
    final line = asMap(raw);
    itemCount += asInt(line['quantity'], 1);
    final box = line['box'] is Map ? asMap(line['box']) : null;
    final label = asString(box?['boxNumber']) ?? asString(box?['boxId']);
    if (label != null && label.isNotEmpty) boxes.add(label);
    final item = line['item'] is Map ? asMap(line['item']) : null;
    final image = asString(item?['imageUrl']);
    if (image != null && image.isNotEmpty) images.add(image);
    final name = asString(item?['name']);
    if (name != null && name.isNotEmpty) names.add(name);
  }
  final created = asString(json['createdAt']) ?? '';
  final rawStatus = (asString(json['status']) ?? '').toUpperCase();
  return OrderSummary(
    id: asString(json['orderNumber']) ?? asString(json['id']) ?? '',
    mongoId: asString(json['id']) ?? '',
    lockerName: asString(locker['lockerName']) ?? 'Locker',
    lockerNumber: asString(locker['lockerId']) ?? '—',
    status: _orderStatusLabel(rawStatus),
    rawStatus: rawStatus,
    total: asDouble(json['grandTotal']),
    placedAt: created.length >= 16 ? created.substring(0, 16).replaceFirst('T', ' ') : created,
    boxes: boxes.toList(),
    itemCount: itemCount,
    paymentStatus: asString(json['paymentStatus']) ?? '',
    collectionToken: asString(json['collectionToken']) ?? '',
    itemImages: images,
    itemNames: names,
    customerName: asString(user['name']) ?? '',
    customerEmail: asString(user['email']) ?? '',
    terminalNumber: locker['terminalNumber'] == null
        ? null
        : asInt(locker['terminalNumber']),
    paidAt: _parseUtcDate(json['paidAt']),
    collectionDeadline: _parseUtcDate(json['collectionDeadline']),
    collectedAt: _parseUtcDate(json['collectedAt']),
    expiredAt: _parseUtcDate(json['expiredAt']),
    cancelledAt: _parseUtcDate(json['cancelledAt']),
  );
}

DateTime? _parseUtcDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  return parsed?.toUtc();
}

ProductCategory mapCategory(Map<String, dynamic> json) {
  final id = asString(json['id']) ?? 'MISC';
  final name = asString(json['name']) ?? id;
  return ProductCategory(
    id: id,
    name: name,
    icon: _categoryIconKey(name),
    itemCount: asInt(json['itemCount']),
  );
}

AdminStats mapAdminStats(Map<String, dynamic> json) {
  return AdminStats(
    totalLockers: asInt(json['totalLockers']),
    availableLockers: asInt(json['availableLockers'], asInt(json['lockersOnline'])),
    ordersToday: asInt(json['ordersToday']),
    revenueToday: asDouble(json['revenueToday']),
    inventoryStatus: asString(json['inventoryStatus']) ?? '—',
    totalUsers: asInt(json['totalUsers']),
    totalAdmins: asInt(json['totalAdmins']),
    totalItems: asInt(json['totalItems']),
    lowStockCount: asInt(json['lowStockCount']),
    outOfStockCount: asInt(json['outOfStockCount']),
    emptyBoxes: asInt(json['emptyBoxes']),
    occupiedBoxes: asInt(json['occupiedBoxes']),
    lockersOnline: asInt(json['lockersOnline']),
    lockersOffline: asInt(json['lockersOffline']),
  );
}

List<ProductCategory> categoriesFromProducts(List<Product> products) {
  final seen = <String>{};
  final out = <ProductCategory>[];
  for (final p in products) {
    if (!seen.add(p.categoryId)) continue;
    final name = p.categoryId
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
    out.add(ProductCategory(
      id: p.categoryId,
      name: name.isEmpty ? 'General' : name,
      icon: _categoryIconKey(name),
      itemCount: products.where((x) => x.categoryId == p.categoryId).length,
    ));
  }
  return out;
}

String _categoryIconKey(String name) {
  final n = name.toLowerCase();
  if (n.contains('snack')) return 'cookie';
  if (n.contains('drink') || n.contains('beverage')) return 'local_cafe';
  if (n.contains('station')) return 'edit';
  if (n.contains('hygiene') || n.contains('care')) return 'soap';
  if (n.contains('tech') || n.contains('electronic')) return 'headphones';
  return 'inventory_2';
}

AdminStats buildAdminStats({
  required List<Locker> lockers,
  required List<OrderSummary> orders,
  required List<InventoryRow> inventory,
}) {
  final online = lockers.where((l) => l.status == 'Online').length;
  final today = DateTime.now().toUtc();
  final todays = orders.where((o) {
    try {
      final d = DateTime.parse(o.placedAt.replaceFirst(' ', 'T'));
      return d.year == today.year && d.month == today.month && d.day == today.day;
    } catch (_) {
      return false;
    }
  }).toList();
  final revenue = todays.fold<double>(0, (sum, o) => sum + o.total);
  final low = inventory.where((r) => r.quantity <= 2).length;
  return AdminStats(
    totalLockers: lockers.length,
    availableLockers: online,
    ordersToday: todays.length,
    revenueToday: revenue,
    inventoryStatus: low == 0
        ? 'Healthy stock levels'
        : '$low item(s) need restock soon',
  );
}
