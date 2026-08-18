import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/collection_countdown.dart';
import '../../../core/utils/order_display.dart';
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
        title: const Text('Orders'),
        automaticallyImplyLeading: false,
      ),
      body: ResponsiveCenter(
        maxWidth: 720,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.orders.isEmpty
                ? EmptyState(
                    message: state.error ?? 'No orders yet',
                    icon: Icons.receipt_long_outlined,
                    actionLabel: 'Browse items',
                    onAction: () => context.go('/home'),
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(ordersViewModelProvider.notifier).refresh(),
                    child: ListView.separated(
                      itemCount: state.orders.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final order = state.orders[index];
                        return _OrderRow(order: order);
                      },
                    ),
                  ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final title = order.itemNames.isNotEmpty
        ? order.itemNames.first
        : shortOrderLabel(order.id);
    final more = order.itemNames.length > 1
        ? ' +${order.itemNames.length - 1}'
        : '';
    final locker = order.lockerName.isNotEmpty
        ? order.lockerName
        : (order.lockerNumber.isNotEmpty ? order.lockerNumber : '');
    final status = friendlyOrderStatus(order.status);
    final ready = order.canCollect;
    final day = order.paidAt != null
        ? formatOrderDay(order.paidAt)
        : formatOrderDay(null, fallback: order.placedAt);

    String? countdown;
    if (ready && order.collectionDeadline != null) {
      final remaining =
          collectionRemaining(deadline: order.collectionDeadline!);
      if (remaining.inSeconds > 0) {
        countdown = formatCollectionCountdown(remaining);
      }
    }

    final detailId =
        order.mongoId.isNotEmpty ? order.mongoId : order.id;

    return InkWell(
      onTap: () => context.push('/orders/${Uri.encodeComponent(detailId)}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (order.itemImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: ProductImage(
                  imageUrl: order.itemImages.first,
                  height: 56,
                  width: 56,
                  borderRadius: 12,
                  iconSize: 22,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title$more',
                    style: AppTextStyles.label.copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      PriceText(
                        order.total,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (locker.isNotEmpty) ...[
                        Text(
                          '  ·  ',
                          style: AppTextStyles.caption,
                        ),
                        Expanded(
                          child: Text(
                            locker,
                            style: AppTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    countdown != null
                        ? '$status · $countdown remaining'
                        : [
                            status,
                            if (day.isNotEmpty) day,
                          ].join(' · '),
                    style: AppTextStyles.caption.copyWith(
                      color: ready
                          ? AppColors.primary
                          : order.isExpired
                              ? AppColors.error
                              : AppColors.muted,
                      fontWeight: ready ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 4),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
