import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models.dart';
import '../../../core/providers/catalog_refresh.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/product_image.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/ux.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  int _qty = 1;
  bool _busy = false;

  Future<void> _addToCart(Product product) async {
    final cart = ref.read(cartViewModelProvider);
    final available = displayStockFor(product, cart);
    if (available < 1 || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(cartViewModelProvider.notifier).addStock(
            product,
            quantity: _qty,
          );
      if (!mounted) return;
      showAppSnackBar(context, '${product.name} added to cart');
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_productDetailsProvider(widget.productId));
    final cart = ref.watch(cartViewModelProvider);

    return async.when(
      loading: () => const PageScaffold(
        title: 'Product details',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Product details',
        body: EmptyState(
          message: userFacingError(e),
          icon: Icons.error_outline_rounded,
        ),
      ),
      data: (data) {
        final product = data.product;
        final locker = data.locker;
        final stock = displayStockFor(product, cart);
        final outOfStock = stock < 1;
        final maxQty = stock.clamp(1, 99);
        if (_qty > maxQty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _qty > maxQty) setState(() => _qty = maxQty);
          });
        }

        return PageScaffold(
          title: product.name,
          bottom: PrimaryButton(
            label: outOfStock
                ? 'Out of stock'
                : _busy
                    ? 'Adding…'
                    : 'Add to Cart',
            isLoading: _busy,
            onPressed: outOfStock || _busy
                ? null
                : () => _addToCart(product),
          ),
          body: ListView(
            children: [
              Hero(
                tag: 'product-image-${product.id}',
                child: ProductImage(
                  imageUrl: product.imageUrl,
                  height: 220,
                  width: double.infinity,
                  borderRadius: 20,
                  icon: Icons.shopping_bag_outlined,
                  iconSize: 64,
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: AppTextStyles.headline),
                    const SizedBox(height: 8),
                    PriceText(
                      product.price,
                      style: AppTextStyles.title.copyWith(
                        color: AppColors.primary,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      outOfStock
                          ? 'Unavailable'
                          : (locker?.name.isNotEmpty == true
                              ? 'Available · ${locker!.name}'
                              : 'Available'),
                      style: AppTextStyles.caption,
                    ),
                    if (!outOfStock) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text('Quantity', style: AppTextStyles.label),
                          const Spacer(),
                          QuantitySelector(
                            quantity: _qty,
                            onDecrement: _qty <= 1
                                ? null
                                : () => setState(() => _qty -= 1),
                            onIncrement: _qty >= maxQty
                                ? null
                                : () => setState(() => _qty += 1),
                          ),
                        ],
                      ),
                    ],
                    if (product.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        product.description.trim(),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductBundle {
  const _ProductBundle({required this.product, this.locker});
  final Product product;
  final Locker? locker;
}

final _productDetailsProvider =
    FutureProvider.family<_ProductBundle, String>((ref, id) async {
  ref.watch(inventoryEpochProvider);
  final product = await ref.read(catalogRepositoryProvider).getStock(id);
  if (product == null) {
    throw StateError('Product not found');
  }
  Locker? locker;
  if (product.lockerId.isNotEmpty) {
    try {
      locker =
          await ref.read(lockerRepositoryProvider).getById(product.lockerId);
    } catch (_) {}
  }
  return _ProductBundle(product: product, locker: locker);
});
