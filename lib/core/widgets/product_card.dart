import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/cart/viewmodels/cart_viewmodel.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'image_placeholder.dart';
import 'product_image.dart';
import 'ui_kit.dart';

/// Catalog stock minus units already in the local cart (optimistic).
int displayStockFor(Product product, CartState cart) {
  final reserved = cart.items
      .where((line) => line.product.id == product.id)
      .fold<int>(0, (sum, line) => sum + line.quantity);
  final available = product.stock - reserved;
  return available < 0 ? 0 : available;
}

/// Reusable product card used on Home, Locker Details, and grids.
///
/// The card body is static unless [onTap] is provided. [onAddToCart] is the
/// primary interactive control (press scale + brief "Added" feedback).
class ProductCard extends ConsumerWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.width,
  });

  final Product product;
  final VoidCallback? onTap;
  final Future<void> Function()? onAddToCart;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartViewModelProvider);
    final stock = displayStockFor(product, cart);

    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight =
            constraints.maxHeight.isFinite && constraints.hasBoundedHeight;
        final available =
            boundedHeight ? constraints.maxHeight : double.infinity;
        final tight = boundedHeight && available < 230;
        final pad = tight ? 8.0 : 12.0;
        final gapAfterImage = tight ? 6.0 : 10.0;
        final buttonH = tight ? 32.0 : 36.0;

        final image = Hero(
          tag: 'product-image-${product.id}',
          child: LayoutBuilder(
            builder: (context, imageConstraints) {
              final h = imageConstraints.hasBoundedHeight
                  ? imageConstraints.maxHeight
                  : 96.0;
              return ProductImage(
                imageUrl: product.imageUrl,
                height: h,
                width: double.infinity,
                icon: Icons.shopping_bag_outlined,
                iconSize: h < 64 ? 28 : 36,
              );
            },
          ),
        );

        final details = <Widget>[
          SizedBox(height: gapAfterImage),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label.copyWith(
              color: AppColors.onBackground,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (product.lockerName.isNotEmpty) product.lockerName,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 4),
          PriceText(product.price),
          const SizedBox(height: 2),
          Text(
            stock < 1 ? 'Out of stock' : 'Available',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: tight ? 6 : 8),
          _AddToCartButton(
            enabled: stock >= 1 && onAddToCart != null,
            height: buttonH,
            onPressed: onAddToCart,
          ),
        ];

        final body = Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (boundedHeight)
                Expanded(child: image)
              else
                SizedBox(height: 96, child: image),
              ...details,
            ],
          ),
        );

        final decorated = DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: body,
        );

        return SizedBox(
          width: width ?? 160,
          height: boundedHeight ? available : null,
          child: onTap == null
              ? decorated
              : Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(16),
                    child: decorated,
                  ),
                ),
        );
      },
    );
  }
}

/// Primary card action — press scale + short "Added" confirmation.
class _AddToCartButton extends StatefulWidget {
  const _AddToCartButton({
    required this.enabled,
    required this.height,
    required this.onPressed,
  });

  final bool enabled;
  final double height;
  final Future<void> Function()? onPressed;

  @override
  State<_AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends State<_AddToCartButton> {
  bool _pressed = false;
  bool _busy = false;
  bool _added = false;

  Future<void> _handlePress() async {
    if (!widget.enabled || _busy || widget.onPressed == null) return;
    setState(() {
      _busy = true;
      _added = false;
    });
    try {
      await widget.onPressed!();
      if (!mounted) return;
      setState(() => _added = true);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) setState(() => _added = false);
    } catch (_) {
      // Caller shows snackbar; keep button ready.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = !widget.enabled
        ? 'Out of stock'
        : _added
            ? 'Added'
            : _busy
                ? 'Adding…'
                : 'Add to Cart';

    return SizedBox(
      width: double.infinity,
      child: Listener(
        onPointerDown: widget.enabled
            ? (_) => setState(() => _pressed = true)
            : null,
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed && widget.enabled ? 0.96 : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: FilledButton.tonal(
            onPressed: widget.enabled && !_busy ? _handlePress : null,
            style: FilledButton.styleFrom(
              backgroundColor: _added
                  ? AppColors.successSoft
                  : AppColors.surfaceMuted,
              foregroundColor:
                  _added ? AppColors.stockHealthyFg : AppColors.primary,
              disabledForegroundColor: AppColors.muted,
              minimumSize: Size.fromHeight(widget.height),
              maximumSize: Size.fromHeight(widget.height),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              textStyle: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

/// Nearby locker info card. Pass [onTap] only when navigation is desired.
/// Home uses this without [onTap] so it stays informational / non-clickable.
class LockerCard extends StatelessWidget {
  const LockerCard({
    super.key,
    required this.locker,
    this.onTap,
  });

  final Locker locker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const ImagePlaceholder(
            height: 64,
            width: 64,
            icon: Icons.lock_outline_rounded,
            size: 28,
            borderRadius: 14,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locker.name,
                  style: AppTextStyles.title.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${locker.distanceMeters}m · ${locker.availableItems} available',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: locker.status == 'Online'
                        ? AppColors.successSoft
                        : AppColors.offlineBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    locker.status == 'Online' ? 'Available' : locker.status,
                    style: AppTextStyles.caption.copyWith(
                      color: locker.status == 'Online'
                          ? AppColors.stockHealthyFg
                          : AppColors.offlineFg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );

    final decoration = BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
      gradient: AppColors.lockerCardGradient,
    );

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(decoration: decoration, child: content),
      ),
    );
  }
}
