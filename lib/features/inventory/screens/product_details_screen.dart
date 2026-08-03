import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/fake_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/image_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ui_kit.dart';

class ProductDetailsScreen extends StatelessWidget {
  const ProductDetailsScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    final product = FakeData.productById(productId);
    final locker = FakeData.lockerById(product.lockerId);

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
              label: 'Add to Cart',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${product.name} added'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          Hero(
            tag: 'product-image-${product.id}',
            child: const ImagePlaceholder(
              height: 220,
              width: double.infinity,
              icon: Icons.shopping_bag_outlined,
              size: 64,
              borderRadius: 20,
            ),
          ),
          const SizedBox(height: 20),
          FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: AppTextStyles.headline),
                const SizedBox(height: 8),
                PriceText(product.price, style: AppTextStyles.title.copyWith(color: AppColors.primary, fontSize: 22)),
                const SizedBox(height: 8),
                Text('${product.stock} in stock at ${locker.name}', style: AppTextStyles.caption),
                const SizedBox(height: 16),
                SoftPanel(
                  child: Text(product.description, style: AppTextStyles.body),
                ),
                const SizedBox(height: 16),
                SoftPanel(
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pickup locker', style: AppTextStyles.label),
                            Text(locker.name, style: AppTextStyles.body),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/locker/${locker.id}'),
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
  }
}
