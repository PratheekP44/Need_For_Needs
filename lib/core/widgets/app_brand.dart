import 'package:flutter/material.dart';

/// Official NeedForNeeds brand asset paths (do not relocate or regenerate).
abstract final class BrandAssets {
  static const String locker = 'assets/images/branding/locker.png';
  static const String title = 'assets/images/branding/title.png';
}

/// Centralized application branding.
///
/// [AppBrand.full] — locker icon + wordmark (headers / splash / auth).
/// [AppBrand.icon] — locker icon only (compact / launcher-style).
/// [AppBrand.wordmark] — wordmark only when the icon is shown separately.
class AppBrand extends StatelessWidget {
  const AppBrand.full({
    super.key,
    this.iconHeight = 48,
    this.titleHeight = 36,
    this.spacing = 12,
    this.alignment = MainAxisAlignment.center,
    this.onLongPress,
  }) : mode = _BrandMode.full;

  const AppBrand.icon({
    super.key,
    this.iconHeight = 48,
    this.onLongPress,
  })  : mode = _BrandMode.icon,
        titleHeight = 36,
        spacing = 12,
        alignment = MainAxisAlignment.center;

  const AppBrand.wordmark({
    super.key,
    this.titleHeight = 36,
  })  : mode = _BrandMode.wordmark,
        iconHeight = 48,
        spacing = 12,
        alignment = MainAxisAlignment.center,
        onLongPress = null;

  /// Vertical brand stack: locker above wordmark (splash / large centers).
  ///
  /// Pass [iconHeight] / [titleHeight] as `null` to size from the viewport
  /// (recommended for splash). Explicit values keep fixed display sizes.
  const AppBrand.stacked({
    super.key,
    this.iconHeight,
    this.titleHeight,
    this.spacing = 20,
    this.onLongPress,
  })  : mode = _BrandMode.stacked,
        alignment = MainAxisAlignment.center;

  final _BrandMode mode;
  final double? iconHeight;
  final double? titleHeight;
  final double spacing;
  final MainAxisAlignment alignment;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final narrow = width < 360;

    final resolvedIcon = iconHeight ??
        (mode == _BrandMode.stacked
            ? (width * 0.24).clamp(80.0, 118.0)
            : 48.0);
    // Wordmark reads larger than the locker on splash — stronger brand presence.
    final resolvedTitle = titleHeight ??
        (mode == _BrandMode.stacked
            ? (width * 0.155).clamp(48.0, 72.0)
            : 36.0);

    Widget child;
    switch (mode) {
      case _BrandMode.icon:
        child = _locker(resolvedIcon);
      case _BrandMode.wordmark:
        child = _title(resolvedTitle, maxWidth: width * 0.9);
      case _BrandMode.stacked:
        child = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _locker(resolvedIcon),
            SizedBox(height: spacing),
            _title(resolvedTitle, maxWidth: width * 0.88),
          ],
        );
      case _BrandMode.full:
        // Always show locker + wordmark. Cap title width so small phones
        // keep both assets proportional without horizontal overflow.
        child = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: alignment,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _locker(resolvedIcon),
            SizedBox(width: spacing),
            Flexible(
              child: _title(
                resolvedTitle,
                maxWidth: width * (narrow ? 0.58 : 0.65),
              ),
            ),
          ],
        );
    }

    if (onLongPress == null) return child;
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  Widget _locker(double height) {
    return Image.asset(
      BrandAssets.locker,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.lock_outline_rounded,
        size: height * 0.85,
      ),
    );
  }

  Widget _title(double height, {required double maxWidth}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Image.asset(
        BrandAssets.title,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => Text(
          'NeedForNeeds',
          style: TextStyle(
            fontSize: height * 0.55,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

enum _BrandMode { full, icon, wordmark, stacked }
