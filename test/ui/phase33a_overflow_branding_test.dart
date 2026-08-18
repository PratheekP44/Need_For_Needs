import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:need_for_needs/core/data/models.dart';
import 'package:need_for_needs/core/widgets/app_brand.dart';
import 'package:need_for_needs/core/widgets/product_card.dart';
import 'package:need_for_needs/features/cart/viewmodels/cart_viewmodel.dart';

void main() {
  testWidgets('AppBrand.stacked title is responsively larger than 30px',
      (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(360, 640)),
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: AppBrand.stacked()),
          ),
        ),
      ),
    );

    final title = tester.widgetList<Image>(find.byType(Image)).firstWhere(
          (img) =>
              img.image is AssetImage &&
              (img.image as AssetImage).assetName == BrandAssets.title,
        );
    expect(title.height, greaterThanOrEqualTo(48));
    expect(title.height, lessThanOrEqualTo(72));
    expect(title.fit, BoxFit.contain);
  });

  testWidgets('ProductCard fits tight grid cell without overflow',
      (tester) async {
    const product = Product(
      id: 'p1',
      name: 'Test Snack Item',
      price: 25,
      stock: 3,
      categoryId: 'c1',
      lockerId: 'l1',
      stockId: 's1',
      lockerName: 'Main Locker',
      availability: 'available',
    );

    Future<void> pumpCard({Future<void> Function()? onAddToCart}) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartViewModelProvider.overrideWith(_EmptyCart.new),
          ],
          child: MediaQuery(
            data: const MediaQueryData(size: Size(360, 640)),
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 154,
                    height: 214, // ~0.72 aspect on ~360px / 2 cols
                    child: ProductCard(
                      product: product,
                      width: 154,
                      onAddToCart: onAddToCart,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // No cart action → CTA is intentionally disabled ("Out of stock" label).
    await pumpCard();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Out of stock'), findsOneWidget);
    expect(find.text('Add to Cart'), findsNothing);

    // With cart action → primary CTA visible, still no overflow.
    await pumpCard(onAddToCart: () async {});
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Add to Cart'), findsOneWidget);
  });
}

class _EmptyCart extends CartViewModel {
  @override
  CartState build() => const CartState(items: []);
}
