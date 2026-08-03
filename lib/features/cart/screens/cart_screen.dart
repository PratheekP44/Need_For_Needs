import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/fake_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/image_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ui_kit.dart';
import '../viewmodels/cart_viewmodel.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(cartViewModelProvider);
    final items = FakeData.cartItems;
    final subtotal = FakeData.cartSubtotal;

    return PageScaffold(
      title: 'Cart',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SoftPanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text('Subtotal', style: AppTextStyles.body),
                const Spacer(),
                PriceText(subtotal),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Checkout',
            onPressed: () => context.push('/checkout'),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return SoftPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ImagePlaceholder(height: 72, width: 72, size: 28, borderRadius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.product.name, style: AppTextStyles.title.copyWith(fontSize: 15)),
                      const SizedBox(height: 4),
                      PriceText(item.product.price),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          QuantitySelector(
                            quantity: item.quantity,
                            onDecrement: () {},
                            onIncrement: () {},
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Item removed (placeholder)'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locker = FakeData.lockers.first;
    final subtotal = FakeData.cartSubtotal;

    return PageScaffold(
      title: 'Checkout',
      bottom: PrimaryButton(
        label: 'Pay \$${subtotal.toStringAsFixed(2)}',
        icon: Icons.lock_outline_rounded,
        onPressed: () => context.go('/payment-success'),
      ),
      body: ListView(
        children: [
          Text('Order summary', style: AppTextStyles.title),
          const SizedBox(height: 12),
          SoftPanel(
            child: Column(
              children: [
                ...FakeData.cartItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}x ${item.product.name}',
                            style: AppTextStyles.body,
                          ),
                        ),
                        PriceText(item.lineTotal, style: AppTextStyles.body),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Text('Total', style: AppTextStyles.title.copyWith(fontSize: 16)),
                    const Spacer(),
                    PriceText(subtotal),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Selected locker', style: AppTextStyles.title),
          const SizedBox(height: 12),
          SoftPanel(
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locker.name,
                        style: AppTextStyles.label.copyWith(color: AppColors.onBackground),
                      ),
                      Text('${locker.distanceMeters}m away', style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SoftPanel(
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Payment method placeholder',
                    style: AppTextStyles.body,
                  ),
                ),
                Text('UPI / Card', style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
