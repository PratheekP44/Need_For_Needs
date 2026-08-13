import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/order_display.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/product_image.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/ux.dart';

class OrderDetailsScreen extends ConsumerWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_orderDetailsProvider(orderId));

    return async.when(
      loading: () => const PageScaffold(
        title: 'Order',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Order',
        body: EmptyState(
          message: userFacingError(e),
          icon: Icons.error_outline_rounded,
          actionLabel: 'Back',
          onAction: () => context.pop(),
        ),
      ),
      data: (order) {
        final title = order.itemNames.isNotEmpty
            ? order.itemNames.first
            : shortOrderLabel(order.id);
        final ready = order.status == 'Ready to collect' && order.canCollect;
        final locker = order.lockerName.isNotEmpty
            ? order.lockerName
            : (order.lockerNumber.isNotEmpty ? order.lockerNumber : 'Locker');

        return PageScaffold(
          title: 'Order',
          bottom: ready
              ? PrimaryButton(
                  label: 'Collect',
                  icon: Icons.lock_open_rounded,
                  onPressed: () => context.push(
                    '/collect-item?orderId=${Uri.encodeComponent(order.mongoId.isNotEmpty ? order.mongoId : order.id)}',
                  ),
                )
              : null,
          body: ListView(
            children: [
              if (order.itemImages.isNotEmpty) ...[
                ProductImage(
                  imageUrl: order.itemImages.first,
                  height: 160,
                  width: double.infinity,
                  borderRadius: 16,
                  iconSize: 48,
                ),
                const SizedBox(height: 20),
              ],
              Text(title, style: AppTextStyles.headline),
              if (order.itemNames.length > 1) ...[
                const SizedBox(height: 6),
                Text(
                  order.itemNames.skip(1).join(', '),
                  style: AppTextStyles.body.copyWith(color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 8),
              PriceText(
                order.total,
                style: AppTextStyles.title.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 28),
              _row('Status', friendlyOrderStatus(order.status)),
              _row('Locker', locker),
              if (order.boxes.isNotEmpty)
                _row('Box', order.boxes.join(', ')),
              if (order.paidAt != null)
                _row('Paid', formatOrderDateTime(order.paidAt)),
              if (order.placedAt.isNotEmpty && order.paidAt == null)
                _row('Ordered', order.placedAt),
              if (order.collectedAt != null)
                _row('Collected', formatOrderDateTime(order.collectedAt)),
              if (order.collectionDeadline != null && order.isPendingCollection)
                _row(
                  'Collect by',
                  formatOrderDateTime(order.collectionDeadline),
                ),
              if (order.isExpired)
                _row('Expired', formatOrderDateTime(order.expiredAt)),
              const SizedBox(height: 28),
              Text('Order ID', style: AppTextStyles.caption),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.id,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: order.id));
                      if (context.mounted) {
                        showAppSnackBar(context, 'Order ID copied');
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.body),
          ),
        ],
      ),
    );
  }
}

final _orderDetailsProvider =
    FutureProvider.family<OrderSummary, String>((ref, id) async {
  return ref.watch(orderRepositoryProvider).getById(id);
});
