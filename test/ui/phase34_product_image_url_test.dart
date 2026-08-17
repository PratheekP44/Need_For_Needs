import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/api/mappers.dart';
import 'package:need_for_needs/core/utils/product_image_url.dart';

void main() {
  group('ProductImageUrlRules', () {
    test('accepts public https and empty', () {
      expect(ProductImageUrlRules.isAcceptable(''), isTrue);
      expect(
        ProductImageUrlRules.isAcceptable('https://cdn.example.com/a.jpg'),
        isTrue,
      );
      expect(ProductImageUrlRules.isAcceptable('/uploads/items/a.jpg'), isTrue);
    });

    test('rejects localhost / LAN / file', () {
      expect(
        ProductImageUrlRules.validationError('http://192.168.1.5/x.jpg'),
        contains('publicly accessible'),
      );
      expect(
        ProductImageUrlRules.validationError('http://localhost/x.jpg'),
        contains('publicly accessible'),
      );
      expect(
        ProductImageUrlRules.validationError('file:///tmp/a.jpg'),
        contains('publicly accessible'),
      );
    });
  });

  group('mapProduct imageUrl', () {
    test('parses canonical imageUrl', () {
      final product = mapStockToProduct({
        'id': 's1',
        'availableQuantity': 2,
        'availability': 'available',
        'item': {
          'id': 'i1',
          'itemId': 'ITM-1',
          'name': 'Cable',
          'sellingPrice': 99,
          'category': 'ELECTRONICS',
          'imageUrl': 'https://cdn.example.com/cable.jpg',
          'description': 'USB-C',
        },
        'locker': {'id': 'l1', 'lockerName': 'Main'},
      });
      expect(product.imageUrl, 'https://cdn.example.com/cable.jpg');
    });

    test('falls back to legacy image key when imageUrl missing', () {
      final product = mapStockToProduct({
        'id': 's1',
        'availableQuantity': 1,
        'item': {
          'id': 'i1',
          'name': 'Snack',
          'sellingPrice': 20,
          'category': 'FOOD',
          'image': 'https://cdn.example.com/snack.png',
        },
        'locker': {'id': 'l1'},
      });
      expect(product.imageUrl, 'https://cdn.example.com/snack.png');
    });

    test('empty imageUrl stays empty for placeholder UI', () {
      final product = mapStockToProduct({
        'id': 's1',
        'availableQuantity': 1,
        'item': {
          'id': 'i1',
          'name': 'NoPic',
          'sellingPrice': 10,
          'category': 'MISC',
          'imageUrl': '',
        },
        'locker': {'id': 'l1'},
      });
      expect(product.imageUrl, '');
    });
  });
}
