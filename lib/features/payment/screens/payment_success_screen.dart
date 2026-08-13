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
import '../../../core/utils/locker_feedback.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/ux.dart';
import '../../../core/utils/order_display.dart';

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
                'Ready to collect',
                style: AppTextStyles.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Reserved at $lockerName',
                style: AppTextStyles.body.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              if (payment != null) ...[
                const SizedBox(height: 16),
                Text(
                  shortOrderLabel(payment.orderNumber),
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
                label: 'Collect',
                icon: Icons.lock_open_rounded,
                onPressed: () {
                  final id = payment?.orderId.isNotEmpty == true
                      ? payment!.orderId
                      : payment?.orderNumber;
                  if (id != null && id.isNotEmpty) {
                    context.push(
                      '/collect-item?orderId=${Uri.encodeComponent(id)}',
                    );
                  } else {
                    context.push('/collect-item');
                  }
                },
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Home',
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
  const CollectItemScreen({super.key, this.orderId});

  /// Optional order id from `/collect-item?orderId=…` (history / details).
  final String? orderId;

  @override
  ConsumerState<CollectItemScreen> createState() => _CollectItemScreenState();
}

class _CollectItemScreenState extends ConsumerState<CollectItemScreen> {
  bool _busy = false;
  String _stage = '';
  String? _error;
  bool _opened = false;
  /// Write OK but no usable hardware ACK — do not claim physical open.
  bool _commandSent = false;
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
    final fromRoute = widget.orderId?.trim() ?? '';
    final orderId = fromRoute.isNotEmpty
        ? fromRoute
        : orderIdForUnlock(payment, null);
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
        OrderSummary? pick;
        for (final o in orders) {
          if (o.canCollect) {
            pick = o;
            break;
          }
        }
        order = pick ?? (orders.isEmpty ? null : orders.first);
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
        _error = userFacingError(e);
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

    final routeId = widget.orderId?.trim() ?? '';
    final orderId = routeId.isNotEmpty
        ? routeId
        : (payment?.orderId.isNotEmpty == true
            ? payment!.orderId
            : (payment?.orderNumber.isNotEmpty == true
                ? payment!.orderNumber
                : (live?.mongoId.isNotEmpty == true
                    ? live!.mongoId
                    : (live?.id ?? ''))));

    if (orderId.isEmpty) {
      setState(() {
        _error = 'No order to collect.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _opened = false;
      _commandSent = false;
      _unlockInfo = null;
      _stage = 'Connecting to locker…';
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
        _stage = 'Opening locker…';
      });

      // Same BLE engine as production Collect / hardware unlock path.
      final engine = ref.read(bleUnlockEngineProvider);
      final result = await engine.unlockOpen(
        request,
        onStage: (stage) {
          if (!mounted) return;
          setState(() {
            _stage = switch (stage) {
              'scan' || 'connect' || 'connected' => 'Connecting to locker…',
              'open' => 'Opening locker…',
              'success' => lockerOpenedHeadline(info.boxNumbers),
              _ => _stage,
            };
          });
        },
      );

      if (!mounted) return;

      if (!result.success) {
        final timedOut = result.stage == 'open_timeout' ||
            (result.message ?? '').toLowerCase().contains('notification timeout');
        setState(() {
          _busy = false;
          _opened = false;
          if (timedOut) {
            // Packet may have reached firmware; do not claim physical open.
            _commandSent = true;
            _stage = 'Unlock command sent';
            _error = null;
          } else {
            _commandSent = false;
            _stage = '';
            _error = _friendlyCollectError(
              result.message ?? 'Couldn\'t open the locker.',
            );
          }
        });
        return;
      }

      setState(() => _stage = 'Opening locker…');
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
        _commandSent = false;
        _stage = lockerOpenedHeadline(info.boxNumbers);
        _error = backendOk
            ? null
            : 'Locker opened. Could not update order status.';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lockerOpenedDetail(info.boxNumbers)),
          ),
        );
      }
      await _refreshOrderFromBackend();
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyCollectError(e);
      setState(() {
        _busy = false;
        _opened = false;
        _commandSent = false;
        _error = message;
        _stage = '';
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
    if (lower.contains('already collected')) return 'Already collected';
    if (lower.contains('403') || lower.contains('forbidden')) {
      return 'Couldn\'t open the locker.';
    }
    if (lower.contains('not ready') || lower.contains('status=')) {
      return 'This order isn\'t ready to collect.';
    }
    if (lower.contains('device not found')) {
      return 'Couldn\'t find the locker. Move closer and try again.';
    }
    if (lower.contains('unable to connect') || lower.contains('connection')) {
      return 'Couldn\'t connect. Check that you\'re near the locker.';
    }
    if (lower.contains('write failed') ||
        lower.contains('notification timeout') ||
        lower.contains('unlock')) {
      return 'Couldn\'t open the locker.';
    }
    if (lower.contains('missing order') || lower.contains('no order')) {
      return 'No order to collect.';
    }
    return 'Couldn\'t open the locker.';
  }

  @override
  Widget build(BuildContext context) {
    final payment = ref.watch(lastPaymentResultProvider);
    final order = _order;
    final itemTitle = order?.itemNames.isNotEmpty == true
        ? order!.itemNames.first
        : shortOrderLabel(payment?.orderNumber ?? order?.id ?? '');
    final lockerName = payment?.lockerName ?? order?.lockerName ?? 'Locker';
    final boxes = payment?.boxes.isNotEmpty == true
        ? payment!.boxes
        : (_unlockInfo?.boxNumbers.map((e) => e.toString()).toList() ??
            order?.boxes ??
            const <String>[]);
    final hasOrder = (widget.orderId?.isNotEmpty == true) ||
        orderIdForUnlock(payment, order).isNotEmpty;
    final expired =
        order?.isExpired == true || _deadlineReached || order?.status == 'Expired';
    final blocked = expired ||
        order?.isCancelled == true ||
        order?.isCollected == true ||
        _opened;
    final collectEnabled = hasOrder && !blocked && !_busy && !_loadingOrder;
    final boxInts = _unlockInfo?.boxNumbers ??
        boxes
            .map((b) => int.tryParse(b.trim()))
            .whereType<int>()
            .toList();

    return PageScaffold(
      title: 'Collect',
      bottom: PrimaryButton(
        label: _busy
            ? 'Opening…'
            : _opened
                ? 'Opened'
                : _error != null || _commandSent
                    ? 'Retry'
                    : expired
                        ? 'Expired'
                        : 'Open Locker',
        icon: _busy
            ? Icons.hourglass_top
            : _opened
                ? Icons.check_circle
                : _error != null || _commandSent
                    ? Icons.refresh_rounded
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
                Text(itemTitle, style: AppTextStyles.headline),
                const SizedBox(height: 6),
                Text(
                  lockerName,
                  style: AppTextStyles.body.copyWith(color: AppColors.muted),
                ),
                if (order?.isPendingCollection == true &&
                    order?.collectionDeadline != null &&
                    !_opened) ...[
                  const SizedBox(height: 28),
                  Text(
                    expired ? 'Expired' : _countdown,
                    style: AppTextStyles.headline.copyWith(
                      fontSize: 36,
                      letterSpacing: 1,
                      color: expired ? AppColors.error : AppColors.primary,
                    ),
                  ),
                  if (!expired)
                    Text(
                      'remaining',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                ],
                if (order?.isCollected == true && !_opened) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Collected',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
                if (order?.isCancelled == true) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Cancelled',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                if (boxes.isNotEmpty && !_opened && !_busy) ...[
                  const SizedBox(height: 32),
                  Text(
                    boxes.length == 1 ? 'Box ${boxes.first}' : 'Boxes',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  if (boxes.length > 1) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: boxes
                          .map(
                            (box) => Container(
                              width: 72,
                              height: 72,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                box,
                                style: AppTextStyles.title,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
                if (_opened) ...[
                  const SizedBox(height: 40),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 72,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lockerOpenedHeadline(boxInts),
                    style: AppTextStyles.headline.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                  if (lockerOpenedBoxesLine(boxInts).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      lockerOpenedBoxesLine(boxInts),
                      style: AppTextStyles.title,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Take your items and close the door.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 36),
                  Text(
                    expired
                        ? 'Collection window ended.'
                        : _commandSent
                            ? 'Unlock command sent. Check the locker, or retry.'
                            : 'Stand near the locker.',
                    style: AppTextStyles.body.copyWith(
                      color: expired
                          ? AppColors.error
                          : _commandSent
                              ? AppColors.primary
                              : AppColors.muted,
                    ),
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(),
                  if (_stage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_stage, style: AppTextStyles.label),
                  ],
                ],
                if (!hasOrder) ...[
                  const SizedBox(height: 16),
                  Text(
                    'No order to collect.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
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

