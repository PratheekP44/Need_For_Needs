import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/api/mappers.dart';
import 'package:need_for_needs/core/data/models.dart';

Product _p({
  required String id,
  required String category,
  required int stock,
  String availability = 'available',
}) {
  return Product(
    id: id,
    name: id,
    price: 10,
    stock: stock,
    categoryId: category,
    lockerId: 'L1',
    stockId: 'S$id',
    availability: availability,
  );
}

void main() {
  group('categoriesFromProducts (available-only)', () {
    test('CASE 1: single available Electronics appears', () {
      final cats = categoriesFromProducts([
        _p(id: 'usb-c', category: 'ELECTRONICS', stock: 1),
      ]);
      expect(cats.map((c) => c.id.toUpperCase()), ['ELECTRONICS']);
    });

    test('CASE 2: Electronics disappears when qty 0 and no others', () {
      final cats = categoriesFromProducts([
        _p(id: 'usb-c', category: 'ELECTRONICS', stock: 0),
      ]);
      expect(cats, isEmpty);
    });

    test('CASE 3: Electronics remains if another available item exists', () {
      final cats = categoriesFromProducts([
        _p(id: 'usb-c', category: 'ELECTRONICS', stock: 0),
        _p(id: 'usb-a', category: 'ELECTRONICS', stock: 2),
      ]);
      expect(cats.map((c) => c.id.toUpperCase()), ['ELECTRONICS']);
      expect(cats.first.itemCount, 1);
    });

    test('unavailable availability flag excluded', () {
      final cats = categoriesFromProducts([
        _p(
          id: 'snack',
          category: 'FOOD',
          stock: 5,
          availability: 'unavailable',
        ),
        _p(id: 'pen', category: 'STATIONERY', stock: 1),
      ]);
      expect(cats.map((c) => c.id.toUpperCase()), ['STATIONERY']);
    });

    test('dedupes multiple categories', () {
      final cats = categoriesFromProducts([
        _p(id: 'a', category: 'ELECTRONICS', stock: 1),
        _p(id: 'b', category: 'STATIONERY', stock: 1),
        _p(id: 'c', category: 'ELECTRONICS', stock: 2),
        _p(id: 'd', category: 'BEVERAGE', stock: 1),
      ]);
      expect(
        cats.map((c) => c.id.toUpperCase()).toList()..sort(),
        ['BEVERAGE', 'ELECTRONICS', 'STATIONERY'],
      );
    });
  });
}
