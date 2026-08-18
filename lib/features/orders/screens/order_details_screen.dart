import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/collection_countdown.dart';
import '../../../core/utils/order_display.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/product_image.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/ux.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  Timer? _timer;
  String _countdown = '';
  bool _deadlineReached = false;
  String? _countdownKey;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _ensureCountdown(OrderSummary order) {
    final key =
        '${order.mongoId}|${order.collectionDeadline?.millisecondsSinceEpoch}|${order.rawStatus}';
    if (_countdownKey == key) return;
    _countdownKey = key;
    _timer?.cancel();
    if (!order.isPendingCollection || order.collectionDeadline == null) {
      _countdown = '';
      _deadlineReached = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _countdownKey != key) return;
      void tick() {
        if (!mounted) return;
        final remaining =
            collectionRemaining(deadline: order.collectionDeadline!);
        setState(() {
          _countdown = formatCollectionCountdown(remaining);
          _deadlineReached = remaining.inSeconds <= 0;
        });
        if (_deadlineReached) _timer?.cancel();
      }

      tick();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderDetailsProvider(widget.orderId));
    ref.listen(orderDetailsProvider(widget.orderId), (prev, next) {
      next.whenData(_ensureCountdown);
    });

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
        _ensureCountdown(order);

        final locker = order.lockerName.isNotEmpty
            ? order.lockerName
            : (order.lockerNumber.isNotEmpty ? order.lockerNumber : 'Locker');
        final statusLabel = friendlyOrderStatus(
          order.rawStatus.isNotEmpty ? order.rawStatus : order.status,
        );
        final expired = order.isExpired || _deadlineReached;
        final canCollect = order.canCollect && !expired;
        final payment = friendlyPaymentLabel(order.paymentStatus);
        final lines = order.lines.isNotEmpty
            ? order.lines
            : order.itemNames
                .map((n) => OrderLineItem(name: n, quantity: 1))
                .toList();

        return PageScaffold(
          title: 'Order',
          bottom: canCollect
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
              Text(
                statusLabel,
                style: AppTextStyles.headline.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 6),
              Text(
                locker,
                style: AppTextStyles.body.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              if (lines.isNotEmpty) ...[
                ...lines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (line.imageUrl.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ProductImage(
                              imageUrl: line.imageUrl,
                              height: 44,
                              width: 44,
                              borderRadius: 10,
                              iconSize: 20,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            '${line.name} × ${line.quantity}',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (line.boxLabel.isNotEmpty)
                          Text(
                            'Box ${line.boxLabel}',
                            style: AppTextStyles.caption,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Text('Total', style: AppTextStyles.caption),
                  const Spacer(),
                  PriceText(
                    order.total,
                    style: AppTextStyles.title.copyWith(fontSize: 20),
                  ),
                ],
              ),
              if (canCollect &&
                  order.collectionDeadline != null &&
                  _countdown.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text(
                  'Collect within',
                  style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  _countdown,
                  style: AppTextStyles.headline.copyWith(
                    fontSize: 32,
                    letterSpacing: 1.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ] else if (expired &&
                  (order.isPendingCollection || order.isExpired)) ...[
                const SizedBox(height: 28),
                Text(
                  'Collection expired',
                  style: AppTextStyles.title.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 28),
              const Divider(height: 1),
              const SizedBox(height: 20),
              if (order.boxes.isNotEmpty)
                _metaRow(
                  'Boxes',
                  order.boxes.map((b) {
                    final n = int.tryParse(b);
                    return n != null ? formatBoxLabel(n) : b;
                  }).join(' · '),
                ),
              if (payment.isNotEmpty) _metaRow('Payment', payment),
              if (order.paidAt != null)
                _metaRow('Paid', formatOrderDateTime(order.paidAt))
              else if (order.placedAt.isNotEmpty)
                _metaRow('Ordered', order.placedAt),
              if (order.collectedAt != null)
                _metaRow('Collected', formatOrderDateTime(order.collectedAt)),
              if (order.isExpired && order.expiredAt != null)
                _metaRow('Expired', formatOrderDateTime(order.expiredAt)),
              if (order.collectionDeadline != null &&
                  order.isPendingCollection &&
                  !canCollect)
                _metaRow(
                  'Deadline',
                  formatOrderDateTime(order.collectionDeadline),
                ),
              const SizedBox(height: 20),
              Text('Order ID', style: AppTextStyles.caption),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      shortOrderLabel(order.id),
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy full order ID',
                    visualDensity: VisualDensity.compact,
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

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
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

final orderDetailsProvider =
    FutureProvider.family<OrderSummary, String>((ref, id) async {
  return ref.watch(orderRepositoryProvider).getById(id);
});
