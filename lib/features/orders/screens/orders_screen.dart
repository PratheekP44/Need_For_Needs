import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/fake_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ui_kit.dart';
import '../viewmodels/orders_viewmodel.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ordersViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Order history'),
        automaticallyImplyLeading: false,
      ),
      body: ResponsiveCenter(
        maxWidth: 720,
        padding: const EdgeInsets.all(20),
        child: ListView.separated(
          itemCount: FakeData.orders.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = FakeData.orders[index];
            final ready = order.status == 'Ready to collect';
            return SoftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.id,
                          style: AppTextStyles.title.copyWith(fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ready ? AppColors.chip : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          order.status,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${order.lockerName} - ${order.lockerNumber}',
                    style: AppTextStyles.caption,
                  ),
                  Text(order.placedAt, style: AppTextStyles.caption),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('${order.itemCount} items', style: AppTextStyles.body),
                      const Spacer(),
                      PriceText(order.total),
                    ],
                  ),
                  if (ready) ...[
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Collect Item',
                      onPressed: () => context.push('/collect-item'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
