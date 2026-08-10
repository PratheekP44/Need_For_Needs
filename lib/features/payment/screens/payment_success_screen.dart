import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/collect_unlock_repository.dart';
import '../../../core/ble/ble.dart';
import '../../../core/data/models.dart';
import '../../../core/payment/checkout_payment_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/collection_countdown.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ui_kit.dart';

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

class CollectItemScreen extends ConsumerStatefulWidget {
  const CollectItemScreen({super.key});

  @override
  ConsumerState<CollectItemScreen> createState() => _CollectItemScreenState();
}

class _CollectItemScreenState extends ConsumerState<CollectItemScreen> {
  bool _busy = false;
  String _stage = '';
  String? _error;
  bool _opened = false;
  CollectUnlockInfo? _unlockInfo;
  OrderSummary? _order;
  bool _loadingOrder = true;
  Timer? _countdownTimer;
  String _countdown = '';
  bool _deadlineReached = false;
  bool _refreshingExpired = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadOrder);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    final payment = ref.read(lastPaymentResultProvider);
    final orderId = orderIdForUnlock(payment, null);
    setState(() {
      _loadingOrder = true;
      _error = null;
    });
    try {
      OrderSummary? order;
      if (orderId.isNotEmpty) {
        order = await ref.read(orderRepositoryProvider).getById(orderId);
      } else {
        final orders = await ref.read(orderRepositoryProvider).list();
        order = orders.isEmpty ? null : orders.first;
      }
      if (!mounted) return;
      setState(() {
        _order = order;
        _loadingOrder = false;
      });
      _startCountdown(order);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingOrder = false;
        _error = e.toString();
      });
    }
  }

  void _startCountdown(OrderSummary? order) {
    _countdownTimer?.cancel();
    _deadlineReached = false;
    if (order == null || !order.isPendingCollection || order.collectionDeadline == null) {
      setState(() => _countdown = '');
      return;
    }
    void tick() {
      if (!mounted) return;
      final deadline = order.collectionDeadline!;
      final remaining = collectionRemaining(deadline: deadline);
      final text = formatCollectionCountdown(remaining);
      final reached = remaining.inSeconds <= 0;
      setState(() {
        _countdown = text;
        _deadlineReached = reached;
      });
      if (reached && !_refreshingExpired) {
        _countdownTimer?.cancel();
        _refreshOrderFromBackend();
      }
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _refreshOrderFromBackend() async {
    if (_refreshingExpired) return;
    _refreshingExpired = true;
    try {
      final id = _order?.mongoId.isNotEmpty == true
          ? _order!.mongoId
          : (_order?.id ?? '');
      if (id.isEmpty) return;
      final refreshed = await ref.read(orderRepositoryProvider).getById(id);
      if (!mounted) return;
      setState(() => _order = refreshed);
      _startCountdown(refreshed);
    } catch (_) {
      // Keep local countdown-at-zero UI; next collect attempt is server-gated.
    } finally {
      _refreshingExpired = false;
    }
  }

  Future<void> _openLocker({
    required OrderPaymentResult? payment,
    required OrderSummary? order,
  }) async {
    if (_busy) return;

    final live = _order ?? order;
    if (live != null && (live.isExpired || _deadlineReached)) {
      setState(() {
        _error = 'Collection expired';
        _stage = 'Collection expired';
      });
      await _refreshOrderFromBackend();
      return;
    }
    if (live != null && (live.isCancelled || live.isCollected)) {
      setState(() {
        _error = live.isCancelled ? 'Order cancelled' : 'Order already collected';
      });
      return;
    }

    final orderId = payment?.orderId.isNotEmpty == true
        ? payment!.orderId
        : (payment?.orderNumber.isNotEmpty == true
            ? payment!.orderNumber
            : (live?.mongoId.isNotEmpty == true
                ? live!.mongoId
                : (live?.id ?? '')));

    if (orderId.isEmpty) {
      setState(() {
        _error =
            'Missing order id. Complete payment again or open a Ready order.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _opened = false;
      _unlockInfo = null;
      _stage = 'Authorizing unlock…';
    });

    try {
      // Collect uses real radio on Android; Virtual MCU elsewhere for bring-up.
      if (!kIsWeb && Platform.isAndroid) {
        ref.read(bleConfigProvider.notifier).useRealBle();
      }

      // Phase 18 — order DB is source of truth (no Unlock JWT, no hardcoded 1).
      // Phase 23 — unlock-info enforces collectionDeadline server-side.
      final collectApi = ref.read(collectUnlockRepositoryProvider);
      final info = await collectApi.fetchUnlockInfo(orderId: orderId);
      final request = info.toUnlockPacketRequest();

      if (!mounted) return;
      setState(() {
        _unlockInfo = info;
        _stage =
            'Opening boxes ${info.boxNumbers.join(', ')} '
            '(Port ${info.port}, Terminal ${info.terminalNumber})…';
      });

      // Same BLE engine as Admin BLE Demo — only packet values differ.
      final engine = ref.read(bleUnlockEngineProvider);
      final result = await engine.unlockOpen(
        request,
        onStage: (stage) {
          if (!mounted) return;
          setState(() {
            _stage = switch (stage) {
              'scan' => 'Scanning for LKRM-V2…',
              'connect' => 'Connecting…',
              'connected' =>
                'Connected — unlocking boxes ${info.boxNumbers.join(', ')}…',
              'open' =>
                'Sending OPEN (port=${info.port}, boxes=${info.boxNumbers})…',
              'success' => 'Locker Opened Successfully',
              _ => _stage,
            };
          });
        },
      );

      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _busy = false;
          _opened = false;
          _stage = result.message ?? 'Unlock failed';
          _error = result.message ?? 'Unlock failed';
        });
        return;
      }

      setState(() => _stage = 'Confirming with server…');
      var backendOk = true;
      try {
        await collectApi.markCollected(orderId: info.orderId);
      } catch (e) {
        backendOk = false;
        BleLog.e('collect-complete failed (BLE already unlocked)', e);
      }

      if (!mounted) return;
      setState(() {
        _busy = false;
        _opened = true;
        _stage = backendOk
            ? 'Boxes ${info.boxNumbers.join(', ')} opened successfully'
            : 'Box opened — server confirm failed';
        _error =
            backendOk ? null : 'Backend authorization failed (collect-complete)';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              backendOk
                  ? 'Boxes ${info.boxNumbers.join(', ')} opened'
                  : 'Locker opened — could not mark order collected',
            ),
          ),
        );
      }
      await _refreshOrderFromBackend();
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyCollectError(e);
      setState(() {
        _busy = false;
        _error = message;
        _stage = 'Error';
      });
      if (message.toLowerCase().contains('expired')) {
        await _refreshOrderFromBackend();
      }
    }
  }

  static String _friendlyCollectError(Object e) {
    final text = e.toString();
    final lower = text.toLowerCase();
    if (lower.contains('expired')) return 'Collection expired';
    if (lower.contains('cancelled')) return 'Order cancelled';
    if (lower.contains('already collected')) return 'Order already collected';
    if (lower.contains('403') || lower.contains('forbidden')) {
      return 'Backend authorization failed';
    }
    if (lower.contains('not ready') || lower.contains('status=')) {
      return 'Backend authorization failed';
    }
    if (lower.contains('device not found')) return 'Device not found';
    if (lower.contains('unable to connect') || lower.contains('connection')) {
      return 'Unable to connect';
    }
    if (lower.contains('write failed')) return 'Write failed';
    if (lower.contains('notification timeout')) return 'Notification timeout';
    if (lower.contains('unlock')) return 'Unlock failed';
    return text;
  }

  String _formatLocal(DateTime? utc) {
    if (utc == null) return '—';
    final local = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final payment = ref.watch(lastPaymentResultProvider);
    final order = _order;
    final id = payment?.orderNumber ?? order?.id ?? '—';
    final lockerName = payment?.lockerName ?? order?.lockerName ?? 'Locker';
    final lockerNumber = payment?.lockerNumber ?? order?.lockerNumber ?? '—';
    final boxes = payment?.boxes.isNotEmpty == true
        ? payment!.boxes
        : (order?.boxes ?? const <String>[]);
    final hasOrder = orderIdForUnlock(payment, order).isNotEmpty;
    final expired =
        order?.isExpired == true || _deadlineReached || order?.status == 'Expired';
    final blocked = expired ||
        order?.isCancelled == true ||
        order?.isCollected == true ||
        _opened;
    final collectEnabled = hasOrder && !blocked && !_busy && !_loadingOrder;

    return PageScaffold(
      title: 'Collect item',
      bottom: PrimaryButton(
        label: _busy
            ? 'Working…'
            : _opened
                ? 'Opened'
                : expired
                    ? 'Collection expired'
                    : 'Open Locker',
        icon: _busy
            ? Icons.hourglass_top
            : _opened
                ? Icons.check_circle
                : expired
                    ? Icons.timer_off_outlined
                    : Icons.lock_open_rounded,
        onPressed: collectEnabled
            ? () => _openLocker(payment: payment, order: order)
            : null,
      ),
      body: _loadingOrder
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SoftPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order number', style: AppTextStyles.caption),
                      const SizedBox(height: 4),
                      Text(id, style: AppTextStyles.title),
                      const SizedBox(height: 12),
                      Text('Order status', style: AppTextStyles.caption),
                      const SizedBox(height: 4),
                      Text(
                        order?.status ?? '—',
                        style: AppTextStyles.label,
                      ),
                      if (order?.paidAt != null) ...[
                        const SizedBox(height: 12),
                        Text('Paid', style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text(
                          _formatLocal(order!.paidAt),
                          style: AppTextStyles.body,
                        ),
                      ],
                      if (order?.collectionDeadline != null) ...[
                        const SizedBox(height: 12),
                        Text('Collection deadline', style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text(
                          _formatLocal(order!.collectionDeadline),
                          style: AppTextStyles.body,
                        ),
                      ],
                      if (order?.isPendingCollection == true &&
                          order?.collectionDeadline != null) ...[
                        const SizedBox(height: 16),
                        Text('Collect within', style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text(
                          expired ? 'Collection expired' : _countdown,
                          style: AppTextStyles.headline.copyWith(
                            fontSize: 28,
                            color: expired ? AppColors.error : AppColors.primary,
                          ),
                        ),
                      ],
                      if (order?.isCollected == true) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Collected ${_formatLocal(order!.collectedAt)}',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.success),
                        ),
                      ],
                      if (order?.isExpired == true) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Collection expired',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.error),
                        ),
                      ],
                      if (order?.isCancelled == true) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Order cancelled',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.error),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text('Locker number', style: AppTextStyles.caption),
                      const SizedBox(height: 4),
                      Text(lockerNumber, style: AppTextStyles.title),
                      const SizedBox(height: 4),
                      Text(
                        lockerName,
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.muted),
                      ),
                      if (_unlockInfo != null) ...[
                        const SizedBox(height: 16),
                        Text('Unlock target (from order)',
                            style: AppTextStyles.caption),
                        const SizedBox(height: 8),
                        Text(
                          'Terminal ${_unlockInfo!.terminalNumber} · '
                          'Port ${_unlockInfo!.port} · '
                          'Boxes ${_unlockInfo!.boxNumbers.join(', ')}',
                          style: AppTextStyles.label,
                        ),
                        if (_unlockInfo!.itemId.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Item ${_unlockInfo!.itemId}',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.muted),
                          ),
                        ],
                      ],
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _opened
                            ? 'Box opened. Retrieve your items and close the door.'
                            : expired
                                ? 'Collection window has ended. Open Locker is disabled.'
                                : 'Stand near LKRM-V2 and tap Open Locker. '
                                    'The app loads Port / Box / Terminal from your order, '
                                    'then uses the same BLE engine as Admin BLE Demo.',
                        style: AppTextStyles.body.copyWith(
                          color: _opened
                              ? AppColors.success
                              : expired
                                  ? AppColors.error
                                  : AppColors.muted,
                        ),
                      ),
                      if (_stage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: LinearProgressIndicator(),
                          ),
                        Text(_stage, style: AppTextStyles.label),
                      ],
                      if (!hasOrder) ...[
                        const SizedBox(height: 12),
                        Text(
                          'No order id available — unlock cannot start.',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.error),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Prefer mongo order id, then order number, then latest order id.
String orderIdForUnlock(OrderPaymentResult? payment, OrderSummary? order) {
  if (payment?.orderId.isNotEmpty == true) return payment!.orderId;
  if (payment?.orderNumber.isNotEmpty == true) return payment!.orderNumber;
  if (order?.mongoId.isNotEmpty == true) return order!.mongoId;
  return order?.id ?? '';
}

