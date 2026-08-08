import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/viewmodels/cart_viewmodel.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'image_placeholder.dart';
import 'product_image.dart';
import 'ui_kit.dart';

/// Catalog stock minus units already in the local cart (optimistic).
int displayStockFor(Product product, CartState cart) {
  final reserved = cart.items
      .where((line) => line.product.id == product.id)
      .fold<int>(0, (sum, line) => sum + line.quantity);
  final available = product.stock - reserved;
  return available < 0 ? 0 : available;
}

/// Reusable product card used on Home, Locker Details, and grids.
class ProductCard extends ConsumerWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.width,
  });

  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartViewModelProvider);
    final stock = displayStockFor(product, cart);

    return SizedBox(
      width: width ?? 160,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'product-image-${product.id}',
                    child: ProductImage(
                      imageUrl: product.imageUrl,
                      height: 96,
                      width: double.infinity,
                      icon: Icons.shopping_bag_outlined,
                      iconSize: 36,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.onBackground,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (product.lockerName.isNotEmpty) product.lockerName,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 4),
                  PriceText(product.price),
                  const SizedBox(height: 2),
                  Text(
                    stock < 1 ? 'Out of stock' : '$stock available',
                    style: AppTextStyles.caption,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: stock < 1 ? null : onAddToCart,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.surfaceMuted,
                        foregroundColor: AppColors.primary,
                        disabledForegroundColor: AppColors.muted,
                        minimumSize: const Size.fromHeight(36),
                        padding: EdgeInsets.zero,
                        textStyle: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      child: Text(stock < 1 ? 'Out of stock' : 'Add to Cart'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LockerCard extends StatelessWidget {
  const LockerCard({
    super.key,
    required this.locker,
    this.onTap,
  });

  final Locker locker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap ?? () => context.push('/locker/${locker.id}'),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            gradient: AppColors.lockerCardGradient,
          ),
          child: Row(
            children: [
              const ImagePlaceholder(
                height: 64,
                width: 64,
                icon: Icons.lock_outline_rounded,
                size: 28,
                borderRadius: 14,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(locker.name, style: AppTextStyles.title.copyWith(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      '${locker.distanceMeters}m away - ${locker.availableItems} items',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: locker.status == 'Online'
                            ? AppColors.successSoft
                            : AppColors.offlineBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        locker.status,
                        style: AppTextStyles.caption.copyWith(
                          color: locker.status == 'Online'
                              ? AppColors.stockHealthyFg
                              : AppColors.offlineFg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
