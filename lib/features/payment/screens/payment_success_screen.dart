import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/ux.dart';

class PaymentSuccessScreen extends ConsumerStatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  ConsumerState<PaymentSuccessScreen> createState() =>
      _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _scale = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payment = ref.watch(lastPaymentResultProvider);
    final lockerName = payment?.lockerName ?? 'your locker';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              ScaleTransition(
                scale: _scale,
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: const BoxDecoration(
                    color: AppColors.chip,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 64,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Payment successful',
                style: AppTextStyles.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Your items are reserved at $lockerName.',
                style: AppTextStyles.body.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              if (payment != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Order ${payment.orderNumber}',
                  style: AppTextStyles.label,
                  textAlign: TextAlign.center,
                ),
                if (payment.gatewayPaymentId.isNotEmpty)
                  Text(
                    'Payment ${payment.gatewayPaymentId}',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                if (payment.boxes.isNotEmpty)
                  Text(
                    'Box ${payment.boxes.join(', ')}',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
              ],
              const Spacer(),
              PrimaryButton(
                label: 'Collect Item',
                icon: Icons.lock_open_rounded,
                onPressed: () => context.push('/collect-item'),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Back to Home',
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CollectItemScreen extends ConsumerWidget {
  const CollectItemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payment = ref.watch(lastPaymentResultProvider);
    final orders = ref.watch(_latestOrderProvider);

    return orders.when(
      loading: () => const PageScaffold(
        title: 'Collect item',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Collect item',
        body: Center(child: Text('$e')),
      ),
      data: (order) {
        final id = payment?.orderNumber ?? order?.id ?? '—';
        final lockerName = payment?.lockerName ?? order?.lockerName ?? 'Locker';
        final lockerNumber =
            payment?.lockerNumber ?? order?.lockerNumber ?? '—';
        final boxes = payment?.boxes.isNotEmpty == true
            ? payment!.boxes
            : (order?.boxes ?? const <String>[]);

        return PageScaffold(
          title: 'Collect item',
          bottom: PrimaryButton(
            label: 'Open Locker',
            icon: Icons.lock_open_rounded,
            onPressed: () => showComingSoon(context, 'BLE locker unlock'),
          ),
          body: ListView(
            children: [
              SoftPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order number', style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Text(id, style: AppTextStyles.title),
                    const SizedBox(height: 16),
                    Text('Locker number', style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Text(lockerNumber, style: AppTextStyles.title),
                    const SizedBox(height: 4),
                    Text(
                      lockerName,
                      style: AppTextStyles.body.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Boxes to open', style: AppTextStyles.title),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: (boxes.isEmpty ? const ['—'] : boxes)
                    .map(
                      (box) => Container(
                        width: 88,
                        height: 88,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          box,
                          style: AppTextStyles.headline.copyWith(fontSize: 22),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              SoftPanel(
                child: Text(
                  'Stand near the locker and tap Open Locker. BLE pairing will be added in a later phase.',
                  style: AppTextStyles.body.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

final _latestOrderProvider = FutureProvider((ref) async {
  if (!ref.watch(authSessionProvider).isAuthenticated) return null;
  final orders = await ref.read(orderRepositoryProvider).list();
  return orders.isEmpty ? null : orders.first;
});
