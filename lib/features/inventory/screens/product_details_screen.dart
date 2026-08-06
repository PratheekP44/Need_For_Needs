import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/models.dart';
import '../../../core/providers/catalog_refresh.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_scaffold.dart';
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
    if (product.stock < 1 || _busy) return;
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
        final outOfStock = product.stock < 1;
        final maxQty = product.stock.clamp(1, 99);

        return PageScaffold(
          title: 'Product details',
          bottom: Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'View Cart',
                  onPressed: () => context.push('/cart'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
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
              ),
            ],
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
                          ? 'Currently unavailable'
                          : '${product.stock} in stock at ${locker?.name ?? 'locker'}',
                      style: AppTextStyles.caption,
                    ),
                    if (!outOfStock) ...[
                      const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
                    SoftPanel(
                      child: Text(
                        product.description,
                        style: AppTextStyles.body,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SoftPanel(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pickup locker',
                                  style: AppTextStyles.label,
                                ),
                                Text(
                                  locker?.name ?? 'Assigned locker',
                                  style: AppTextStyles.body,
                                ),
                              ],
                            ),
                          ),
                          if (locker != null)
                            TextButton(
                              onPressed: () =>
                                  context.push('/locker/${locker.id}'),
                              child: const Text('Open'),
                            ),
                        ],
                      ),
                    ),
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
