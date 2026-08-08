import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/product_image.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/ux.dart';
import '../viewmodels/orders_viewmodel.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ordersViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Order history'),
        automaticallyImplyLeading: false,
      ),
      body: ResponsiveCenter(
        maxWidth: 720,
        padding: const EdgeInsets.all(20),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.orders.isEmpty
                ? EmptyState(
                    message: state.error ?? 'No orders yet',
                    icon: Icons.receipt_long_outlined,
                    actionLabel: 'Browse lockers',
                    onAction: () => context.go('/home'),
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(ordersViewModelProvider.notifier).refresh(),
                    child: ListView.separated(
                      itemCount: state.orders.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = state.orders[index];
                        final ready = order.status == 'Ready to collect';
                        final chip = _statusStyle(order.status);
                        return SoftPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      order.id,
                                      style: AppTextStyles.title
                                          .copyWith(fontSize: 16),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: chip.$1,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      order.status,
                                      style: AppTextStyles.caption.copyWith(
                                        color: chip.$2,
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
                              if (order.boxes.isNotEmpty)
                                Text(
                                  'Box ${order.boxes.join(', ')}',
                                  style: AppTextStyles.caption,
                                ),
                              Text(order.placedAt, style: AppTextStyles.caption),
                              if (order.paymentStatus.isNotEmpty)
                                Text(
                                  'Payment: ${order.paymentStatus}',
                                  style: AppTextStyles.caption,
                                ),
                              if (order.itemNames.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  order.itemNames.take(3).join(', '),
                                  style: AppTextStyles.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (order.itemImages.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 48,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: order.itemImages.length.clamp(0, 4),
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (context, i) {
                                      return ProductImage(
                                        imageUrl: order.itemImages[i],
                                        height: 48,
                                        width: 48,
                                        borderRadius: 8,
                                        iconSize: 18,
                                      );
                                    },
                                  ),
                                ),
                              ],
                              if (order.collectionToken.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Token: ${order.collectionToken}',
                                  style: AppTextStyles.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    '${order.itemCount} items',
                                    style: AppTextStyles.body,
                                  ),
                                  const Spacer(),
                                  PriceText(order.total),
                                ],
                              ),
                              if (ready) ...[
                                const SizedBox(height: 12),
                                PrimaryButton(
                                  label: 'Collect Item',
                                  onPressed: () =>
                                      context.push('/collect-item'),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  (Color, Color) _statusStyle(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('ready')) {
      return (AppColors.chip, AppColors.primary);
    }
    if (lower.contains('cancel')) {
      return (AppColors.cancelBg, AppColors.error);
    }
    if (lower.contains('collect') || lower.contains('complete')) {
      return (AppColors.surfaceMuted, AppColors.muted);
    }
    if (lower.contains('paid') || lower.contains('confirm')) {
      return (AppColors.paidBg, AppColors.paidFg);
    }
    return (AppColors.surfaceMuted, AppColors.primary);
  }
}
