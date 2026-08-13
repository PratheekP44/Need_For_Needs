import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/models.dart';
import '../../../core/providers/catalog_refresh.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/product_image.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/ux.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../viewmodels/cart_viewmodel.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartViewModelProvider);
    final items = cart.items;
    final grandTotal =
        cart.grandTotal > 0 ? cart.grandTotal : cart.subtotal + cart.tax;
    // Only block destructive clear / checkout while an initial fetch is empty.
    final initialLoading = cart.isLoading && items.isEmpty;

    return PageScaffold(
      title: 'Cart',
      actions: [
        if (items.isNotEmpty)
          TextButton(
            onPressed: initialLoading
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear cart?'),
                        content: const Text(
                          'Remove all items from your cart.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    try {
                      await ref.read(cartViewModelProvider.notifier).clearCart();
                      if (context.mounted) {
                        showAppSnackBar(context, 'Cart cleared');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showAppSnackBar(context, userFacingError(e));
                      }
                    }
                  },
            child: const Text('Clear'),
          ),
      ],
      bottom: items.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SoftPanel(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text('Subtotal', style: AppTextStyles.body),
                          const Spacer(),
                          PriceText(cart.subtotal),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('GST', style: AppTextStyles.body),
                          const Spacer(),
                          PriceText(cart.tax),
                        ],
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Text(
                            'Grand Total',
                            style: AppTextStyles.title.copyWith(fontSize: 15),
                          ),
                          const Spacer(),
                          PriceText(grandTotal),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Checkout',
                  onPressed:
                      initialLoading ? null : () => context.push('/checkout'),
                ),
              ],
            ),
      body: initialLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? EmptyState(
                  message: cart.error ?? 'Your cart is empty',
                  icon: Icons.shopping_cart_outlined,
                  actionLabel: 'Browse items',
                  onAction: () => context.go('/home'),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final maxStock = item.product.stock;
                    final syncing = item.cartItemId.startsWith('local-');
                    return SoftPanel(
                      key: ValueKey(item.cartItemId),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProductImage(
                            imageUrl: item.product.imageUrl,
                            height: 72,
                            width: 72,
                            iconSize: 28,
                            borderRadius: 12,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  style: AppTextStyles.title.copyWith(
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                PriceText(item.product.price),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    QuantitySelector(
                                      quantity: item.quantity,
                                      onDecrement: syncing
                                          ? null
                                          : () async {
                                              try {
                                                await ref
                                                    .read(
                                                      cartViewModelProvider
                                                          .notifier,
                                                    )
                                                    .setQuantity(
                                                      item.cartItemId,
                                                      item.quantity - 1,
                                                    );
                                              } catch (e) {
                                                if (context.mounted) {
                                                  showAppSnackBar(
                                                    context,
                                                    userFacingError(e),
                                                  );
                                                }
                                              }
                                            },
                                      onIncrement: syncing ||
                                              (maxStock > 0 &&
                                                  item.quantity >= maxStock)
                                          ? null
                                          : () async {
                                              try {
                                                await ref
                                                    .read(
                                                      cartViewModelProvider
                                                          .notifier,
                                                    )
                                                    .setQuantity(
                                                      item.cartItemId,
                                                      item.quantity + 1,
                                                    );
                                              } catch (e) {
                                                if (context.mounted) {
                                                  showAppSnackBar(
                                                    context,
                                                    userFacingError(e),
                                                  );
                                                }
                                              }
                                            },
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: syncing
                                          ? null
                                          : () async {
                                              try {
                                                await ref
                                                    .read(
                                                      cartViewModelProvider
                                                          .notifier,
                                                    )
                                                    .remove(item.cartItemId);
                                              } catch (e) {
                                                if (context.mounted) {
                                                  showAppSnackBar(
                                                    context,
                                                    userFacingError(e),
                                                  );
                                                }
                                              }
                                            },
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.error,
                                      ),
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

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _paying = false;
  String _progress = '';

  Future<void> _pay() async {
    setState(() {
      _paying = true;
      _progress = 'Starting payment…';
    });
    try {
      final result = await ref.read(checkoutPaymentServiceProvider).payCart(
            onProgress: (step) {
              if (mounted) setState(() => _progress = step);
            },
          );
      ref.read(lastPaymentResultProvider.notifier).setResult(result);
      await refreshCatalogSurfaces(ref);
      if (!mounted) return;
      context.go('/payment-success');
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, userFacingError(e));
    } finally {
      if (mounted) {
        setState(() {
          _paying = false;
          _progress = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartViewModelProvider);
    final home = ref.watch(homeViewModelProvider);
    final lockerId =
        cart.items.isNotEmpty ? cart.items.first.product.lockerId : '';
    Locker? matchedLocker;
    for (final locker in home.lockers) {
      if (locker.id == lockerId) {
        matchedLocker = locker;
        break;
      }
    }
    matchedLocker ??= home.lockers.isNotEmpty ? home.lockers.first : null;
    final subtotal = cart.subtotal;
    final tax = cart.tax;
    final grandTotal =
        cart.grandTotal > 0 ? cart.grandTotal : subtotal + tax;

    if (cart.items.isEmpty) {
      return PageScaffold(
        title: 'Checkout',
        body: EmptyState(
          message: 'Your cart is empty',
          icon: Icons.shopping_bag_outlined,
          actionLabel: 'Back to cart',
          onAction: () => context.go('/cart'),
        ),
        bottom: PrimaryButton(
          label: 'Pay',
          onPressed: null,
        ),
      );
    }

    return PageScaffold(
      title: 'Checkout',
      bottom: PrimaryButton(
        label: _paying
            ? 'Processing…'
            : 'Pay ${MoneyFormat.format(grandTotal)}',
        icon: Icons.lock_outline_rounded,
        isLoading: _paying,
        onPressed: _paying ? null : _pay,
      ),
      body: ListView(
        children: [
          Text('Order summary', style: AppTextStyles.title),
          const SizedBox(height: 12),
          SoftPanel(
            child: Column(
              children: [
                ...cart.items.map(
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
                        PriceText(
                          item.computedLineTotal,
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                _AmountRow(label: 'Subtotal', amount: subtotal),
                const SizedBox(height: 6),
                _AmountRow(label: 'GST', amount: tax),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Grand Total',
                      style: AppTextStyles.title.copyWith(fontSize: 16),
                    ),
                    const Spacer(),
                    PriceText(grandTotal),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Pickup locker', style: AppTextStyles.title),
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
                        matchedLocker?.name ?? 'Assigned at payment',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.onBackground,
                        ),
                      ),
                      Text(
                        matchedLocker != null
                            ? '${matchedLocker.distanceMeters}m away'
                            : 'Location confirmed after payment',
                        style: AppTextStyles.caption,
                      ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pay securely',
                        style: AppTextStyles.body,
                      ),
                      if (_paying && _progress.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          _progress,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
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

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.body),
        const Spacer(),
        PriceText(amount, style: AppTextStyles.body),
      ],
    );
  }
}
