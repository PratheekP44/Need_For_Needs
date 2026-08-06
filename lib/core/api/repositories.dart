import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_client.dart';
import 'auth_debug.dart';
import 'mappers.dart';
import '../data/models.dart';
import '../location/location_service.dart';

class AuthRepository {
  AuthRepository(this._api, this._session);
  final ApiClient _api;
  final SessionStore _session;

  Future<AppUser> login({required String email, required String password}) async {
    authLog('POST /auth/login email=$email');
    final data = asMap(await _api.post(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
      auth: false,
    ));
    authLog(
      'Login response keys=${data.keys.toList()} '
      'hasAccess=${asString(data['accessToken'])?.isNotEmpty == true} '
      'hasRefresh=${asString(data['refreshToken'])?.isNotEmpty == true} '
      'hasUser=${data['user'] != null}',
    );
    await _persistAuth(data);
    return fetchProfile();
  }

  Future<AppUser> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final payload = {
      'name': name.trim(),
      'email': email.trim(),
      'phone': _normalizePhone(phone),
      'password': password,
      'accountType': 'user',
    };
    authLog('POST /auth/signup body=$payload');
    final data = asMap(await _api.post(
      '/auth/signup',
      body: payload,
      auth: false,
    ));
    authLog(
      'Signup response keys=${data.keys.toList()} '
      'hasAccess=${asString(data['accessToken'])?.isNotEmpty == true} '
      'hasRefresh=${asString(data['refreshToken'])?.isNotEmpty == true}',
    );
    await _persistAuth(data);
    return fetchProfile();
  }

  Future<AppUser> fetchProfile() async {
    authLog('GET /auth/profile');
    final data = asMap(await _api.get('/auth/profile'));
    // Backend returns `{ user: {...} }` inside `data`.
    final userMap = data.containsKey('user') ? asMap(data['user']) : data;
    final role =
        asString(userMap['accountType']) ?? asString(userMap['role']) ?? 'user';
    final user = AppUser(
      name: asString(userMap['name']) ?? 'User',
      email: asString(userMap['email']) ?? '',
      phone: asString(userMap['phone']) ?? '',
      savedLocations: const [],
      role: role,
      joinedDate: asString(userMap['joinedDate']) ??
          asString(userMap['createdAt']) ??
          '',
      orderCount: asInt(userMap['orderCount']),
      totalPurchases: asDouble(userMap['totalPurchases']),
    );
    authLog(
      'Profile fetched name=${user.name} email=${user.email} '
      'phone=${user.phone} role=${user.role}',
    );
    await _session.saveSession(
      accessToken: (await _session.accessToken) ?? '',
      refreshToken: (await _session.refreshToken) ?? '',
      role: role,
      name: user.name,
      email: user.email,
      phone: user.phone,
    );
    return user;
  }

  Future<void> logout() async {
    authLog('Logout');
    try {
      final refresh = await _session.refreshToken;
      await _api.post('/auth/logout', body: {
        'refreshToken': ?refresh,
      });
    } catch (_) {
      // Clear local session even if network logout fails.
    }
    await _session.clear();
  }

  Future<AppUser?> restore() async {
    final has = await _session.hasSession;
    authLog('Restore session hasSession=$has');
    if (!has) return null;

    try {
      return await fetchProfile();
    } on ApiException catch (e) {
      authLog('Restore profile failed (${e.statusCode}): ${e.message}');
      if (e.statusCode == 401) {
        final refreshed = await _api.tryRefreshTokens();
        authLog('Restore refresh attempt=$refreshed');
        if (refreshed) {
          try {
            return await fetchProfile();
          } catch (e2) {
            authLog('Restore after refresh failed: $e2');
          }
        }
      }
      await _session.clear();
      return null;
    } catch (e) {
      authLog('Restore failed: $e');
      await _session.clear();
      return null;
    }
  }

  Future<void> _persistAuth(Map<String, dynamic> data) async {
    final userMap = asMap(data['user']);
    final role =
        asString(userMap['accountType']) ?? asString(userMap['role']) ?? 'user';
    final access = asString(data['accessToken']) ?? '';
    final refresh = asString(data['refreshToken']) ?? '';
    if (access.isEmpty) {
      throw ApiException('Authentication response missing accessToken');
    }
    await _session.saveSession(
      accessToken: access,
      refreshToken: refresh,
      role: role,
      name: asString(userMap['name']),
      email: asString(userMap['email']),
      phone: asString(userMap['phone']),
    );
    authLog('Auth tokens persisted for role=$role');
  }

  /// Backend expects `^\+?[0-9]{7,15}$` — strip spaces/dashes/parens from UI input.
  static String _normalizePhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return trimmed;
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return hasPlus ? '+$digits' : digits;
  }
}


class LockerRepository {
  LockerRepository(this._api, this._location);
  final ApiClient _api;
  final LocationService _location;

  Future<List<Locker>> list() async {
    final position = await _resolvePosition();
    final query = <String, String>{'limit': '50'};
    if (position != null) {
      query['lat'] = '${position.latitude}';
      query['lng'] = '${position.longitude}';
      query['sort'] = 'distance';
    }
    final data = asMap(await _api.get('/lockers', query: query));
    final rows = asList(data['lockers']).map((e) => asMap(e)).toList();

    final lockers = <Locker>[];
    for (final row in rows) {
      var distance = row['distanceInMeters'] is num
          ? (row['distanceInMeters'] as num).toInt()
          : 0;
      final lat = row['latitude'];
      final lng = row['longitude'];
      if (position != null && lat is num && lng is num) {
        distance = _location.distanceMeters(
          fromLat: position.latitude,
          fromLng: position.longitude,
          toLat: lat.toDouble(),
          toLng: lng.toDouble(),
        );
      }
      lockers.add(mapLocker(row, distanceMeters: distance));
    }
    lockers.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return lockers;
  }

  Future<Locker> getById(String id, {int availableItems = 0}) async {
    final position = await _resolvePosition();
    final query = <String, String>{};
    if (position != null) {
      query['lat'] = '${position.latitude}';
      query['lng'] = '${position.longitude}';
    }
    final data = asMap(await _api.get('/lockers/$id', query: query.isEmpty ? null : query));
    var distance = asInt(data['distanceInMeters'], 0);
    final lat = data['latitude'];
    final lng = data['longitude'];
    if (position != null && lat is num && lng is num) {
      distance = _location.distanceMeters(
        fromLat: position.latitude,
        fromLng: position.longitude,
        toLat: lat.toDouble(),
        toLng: lng.toDouble(),
      );
    }
    return mapLocker(data, distanceMeters: distance, availableItems: availableItems);
  }

  Future<_LatLng?> _resolvePosition() async {
    final p = await _location.currentPosition();
    if (p == null) return null;
    return _LatLng(p.latitude, p.longitude);
  }
}

class _LatLng {
  _LatLng(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

class CatalogRepository {
  CatalogRepository(this._api);
  final ApiClient _api;

  Future<List<Product>> listStock({
    String? lockerId,
    String? search,
    String? category,
    int page = 1,
    int limit = 40,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      'page': '$page',
      'availability': 'available',
    };
    if (lockerId != null && lockerId.isNotEmpty) {
      query['locker'] = lockerId;
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (category != null && category.isNotEmpty && category != 'all') {
      query['category'] = category.toUpperCase();
    }
    final data = asMap(await _api.get('/stock', query: query));
    return asList(data['stock'])
        .map((e) => mapStockToProduct(asMap(e)))
        .where((p) => p.hasCartMapping)
        .toList();
  }

  Future<HomeCatalog> fetchHomeCatalog({String? lockerId}) async {
    final query = <String, String>{'limit': '12'};
    if (lockerId != null && lockerId.isNotEmpty) query['locker'] = lockerId;
    final data = asMap(await _api.get('/catalog/home', query: query));
    final sections = asList(data['sections']);
    List<Product> section(String key) {
      for (final raw in sections) {
        final m = asMap(raw);
        if (asString(m['key']) == key) {
          return asList(m['items'])
              .map((e) => mapStockToProduct(asMap(e)))
              .where((p) => p.hasCartMapping)
              .toList();
        }
      }
      return const [];
    }

    final categories = asList(data['categories']).map((e) => mapCategory(asMap(e))).toList();
    return HomeCatalog(
      popular: section('popular'),
      newest: section('newest'),
      recommended: section('recommended'),
      recent: section('recent'),
      categories: categories,
    );
  }

  Future<List<ProductCategory>> listCategories() async {
    final data = asMap(await _api.get('/catalog/categories'));
    return asList(data['categories']).map((e) => mapCategory(asMap(e))).toList();
  }

  Future<AdminStats> fetchAdminStats() async {
    final data = asMap(await _api.get('/admin/stats'));
    return mapAdminStats(asMap(data['stats']));
  }

  Future<Product?> getStock(String id) async {
    final data = asMap(await _api.get('/stock/$id'));
    final stock = data.containsKey('stock') ? asMap(data['stock']) : data;
    final product = mapStockToProduct(stock);
    if (product.id.isEmpty) return null;
    return product;
  }

  Future<List<InventoryRow>> listInventory() async {
    final data = asMap(await _api.get('/stock', query: {'limit': '100'}));
    return asList(data['stock']).map((e) => mapStockToInventory(asMap(e))).toList();
  }

  Future<List<Map<String, dynamic>>> listItems() async {
    final data = asMap(await _api.get('/items', query: {'limit': '100'}));
    return asList(data['items']).map((e) => asMap(e)).toList();
  }

  Future<Map<String, dynamic>> getItem(String id) async {
    final data = asMap(await _api.get('/items/$id'));
    return asMap(data['item']);
  }

  Future<Map<String, dynamic>> createItem(Map<String, dynamic> body) async {
    final data = asMap(await _api.post('/items', body: body));
    return asMap(data['item']);
  }

  Future<Map<String, dynamic>> updateItem(
    String id,
    Map<String, dynamic> body,
  ) async {
    final data = asMap(await _api.put('/items/$id', body: body));
    return asMap(data['item']);
  }

  Future<Map<String, dynamic>> uploadItemImage({
    required String itemId,
    required List<int> bytes,
    required String filename,
  }) async {
    if (bytes.isEmpty) {
      throw ApiException('Image bytes are empty', statusCode: 400);
    }
    final safeName = _safeImageFilename(filename);
    final file = http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: safeName,
      contentType: _imageMediaType(safeName),
    );
    final data = asMap(await _api.postMultipart(
      '/items/$itemId/image',
      files: [file],
    ));
    return asMap(data['item']);
  }

  Future<Map<String, dynamic>> removeItemImage(String itemId) async {
    final data = asMap(await _api.delete('/items/$itemId/image'));
    return asMap(data['item']);
  }

  static String _safeImageFilename(String filename) {
    final trimmed = filename.trim();
    final base = trimmed.isEmpty ? 'product.jpg' : trimmed;
    final lower = base.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif')) {
      return base;
    }
    return '$base.jpg';
  }

  static MediaType _imageMediaType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'gif':
        return MediaType('image', 'gif');
      case 'jpg':
      case 'jpeg':
      default:
        return MediaType('image', 'jpeg');
    }
  }

  Future<Map<String, dynamic>> assignStock(Map<String, dynamic> body) async {
    final data = asMap(await _api.post('/stock', body: body));
    return asMap(data['stock']);
  }

  /// Delete a single physical stock record (one box). Admin only.
  Future<Map<String, dynamic>> deleteStock(String stockId) async {
    final data = asMap(await _api.delete('/stock/$stockId'));
    return data;
  }

  /// Stock [quantity] units into [quantity] distinct empty boxes (unit-box model).
  Future<Map<String, dynamic>> assignStockBatch({
    required String itemId,
    required int quantity,
    required List<String> boxIds,
  }) async {
    final data = asMap(await _api.post('/stock/batch', body: {
      'item': itemId,
      'quantity': quantity,
      'boxes': boxIds,
      'reorderLevel': 0,
    }));
    return data;
  }

  Future<List<Map<String, dynamic>>> listEmptyBoxes({
    String? lockerId,
  }) async {
    // Backend listBoxesValidator: limit max 100 (also capped in parseListQuery).
    final query = <String, String>{
      'unassigned': 'true',
      'limit': '100',
    };
    if (lockerId != null && lockerId.isNotEmpty) {
      query['locker'] = lockerId;
    }
    authLog('GET /boxes query=$query');
    final data = asMap(await _api.get('/boxes', query: query));
    return asList(data['boxes']).map((e) => asMap(e)).toList();
  }
}

class CartRepository {
  CartRepository(this._api);
  final ApiClient _api;

  Map<String, dynamic> _unwrapCart(dynamic raw) {
    final data = asMap(raw);
    return data.containsKey('cart') ? asMap(data['cart']) : data;
  }

  Future<({List<CartLine> items, double subtotal, double tax, double grandTotal})>
      getCart() async {
    final cart = _unwrapCart(await _api.get('/cart'));
    final items = asList(cart['items']).map((e) => mapCartLine(asMap(e))).toList();
    return (
      items: items,
      subtotal: asDouble(cart['subtotal']),
      tax: asDouble(cart['tax']),
      grandTotal: asDouble(cart['grandTotal'], asDouble(cart['subtotal'])),
    );
  }

  Future<({List<CartLine> items, double subtotal, double tax, double grandTotal})>
      add({
    String? itemId,
    String? stockId,
    String? lockerId,
    String? boxId,
    int quantity = 1,
  }) async {
    final body = <String, dynamic>{'quantity': quantity};
    if (itemId != null && itemId.isNotEmpty) {
      body['itemId'] = itemId;
      if (lockerId != null && lockerId.isNotEmpty && lockerId != 'null') {
        body['lockerId'] = lockerId;
      }
    } else {
      if (stockId == null ||
          stockId.isEmpty ||
          lockerId == null ||
          lockerId.isEmpty ||
          boxId == null ||
          boxId.isEmpty ||
          lockerId == 'null' ||
          boxId == 'null') {
        throw ApiException(
          'Cannot add to cart: missing product mapping',
        );
      }
      body['stockId'] = stockId;
      body['lockerId'] = lockerId;
      body['boxId'] = boxId;
    }
    final cart = _unwrapCart(await _api.post('/cart/add', body: body));
    final items = asList(cart['items']).map((e) => mapCartLine(asMap(e))).toList();
    return (
      items: items,
      subtotal: asDouble(cart['subtotal']),
      tax: asDouble(cart['tax']),
      grandTotal: asDouble(cart['grandTotal'], asDouble(cart['subtotal'])),
    );
  }

  Future<({List<CartLine> items, double subtotal, double tax, double grandTotal})>
      update({
    required String cartItemId,
    required int quantity,
  }) async {
    final cart = _unwrapCart(await _api.put('/cart/update', body: {
      'cartItemId': cartItemId,
      'quantity': quantity,
    }));
    final items = asList(cart['items']).map((e) => mapCartLine(asMap(e))).toList();
    return (
      items: items,
      subtotal: asDouble(cart['subtotal']),
      tax: asDouble(cart['tax']),
      grandTotal: asDouble(cart['grandTotal'], asDouble(cart['subtotal'])),
    );
  }

  Future<({List<CartLine> items, double subtotal, double tax, double grandTotal})>
      remove(
    String cartItemId,
  ) async {
    final id = cartItemId.trim();
    if (id.isEmpty || id == 'null' || id == 'undefined') {
      throw ApiException('Invalid cart item id');
    }
    final cart = _unwrapCart(await _api.delete('/cart/remove/$id'));
    final items = asList(cart['items']).map((e) => mapCartLine(asMap(e))).toList();
    return (
      items: items,
      subtotal: asDouble(cart['subtotal']),
      tax: asDouble(cart['tax']),
      grandTotal: asDouble(cart['grandTotal'], asDouble(cart['subtotal'])),
    );
  }

  Future<({List<CartLine> items, double subtotal, double tax, double grandTotal})>
      clear() async {
    final cart = _unwrapCart(await _api.delete('/cart/clear'));
    final items = asList(cart['items']).map((e) => mapCartLine(asMap(e))).toList();
    return (
      items: items,
      subtotal: asDouble(cart['subtotal']),
      tax: asDouble(cart['tax']),
      grandTotal: asDouble(cart['grandTotal'], asDouble(cart['subtotal'])),
    );
  }
}

class OrderRepository {
  OrderRepository(this._api);
  final ApiClient _api;

  Future<OrderSummary> checkout({double discount = 0}) async {
    final data = asMap(await _api.post('/checkout', body: {
      if (discount > 0) 'discount': discount,
    }));
    final order = data.containsKey('order') ? asMap(data['order']) : data;
    return mapOrder(order);
  }

  Future<List<OrderSummary>> list({String? status}) async {
    final query = <String, String>{'limit': '50'};
    if (status != null) query['status'] = status;
    final data = asMap(await _api.get('/orders', query: query));
    return asList(data['orders']).map((e) => mapOrder(asMap(e))).toList();
  }

  Future<OrderSummary> getById(String id) async {
    final data = asMap(await _api.get('/orders/$id'));
    final order = data.containsKey('order') ? asMap(data['order']) : data;
    return mapOrder(order);
  }

  /// Raw order map (for payment create which needs mongo id).
  Future<Map<String, dynamic>> getRaw(String id) async {
    final data = asMap(await _api.get('/orders/$id'));
    return data.containsKey('order') ? asMap(data['order']) : data;
  }

  Future<Map<String, dynamic>> checkoutRaw({double discount = 0}) async {
    final data = asMap(await _api.post('/checkout', body: {
      if (discount > 0) 'discount': discount,
    }));
    return data.containsKey('order') ? asMap(data['order']) : data;
  }
}

class PaymentRepository {
  PaymentRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> createOrder({required String orderId}) async {
    return asMap(await _api.post('/payment/create-order', body: {
      'orderId': orderId,
    }));
  }

  Future<Map<String, dynamic>> verify({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    String? paymentMethod,
  }) async {
    return asMap(await _api.post('/payment/verify', body: {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
      'paymentMethod': ?paymentMethod,
    }));
  }

  Future<Map<String, dynamic>> fail({
    required String orderId,
    String? reason,
  }) async {
    return asMap(await _api.post('/payment/fail', body: {
      'orderId': orderId,
      'reason': ?reason,
    }));
  }
}
