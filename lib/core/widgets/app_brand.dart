import 'package:flutter/material.dart';

/// Official Need For Needs brand asset paths (do not relocate or regenerate).
abstract final class BrandAssets {
  static const String locker = 'assets/images/locker.png';
  static const String title = 'assets/images/title.png';
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
  const AppBrand.stacked({
    super.key,
    this.iconHeight = 88,
    this.titleHeight = 28,
    this.spacing = 18,
    this.onLongPress,
  })  : mode = _BrandMode.stacked,
        alignment = MainAxisAlignment.center;

  final _BrandMode mode;
  final double iconHeight;
  final double titleHeight;
  final double spacing;
  final MainAxisAlignment alignment;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 360;

    Widget child;
    switch (mode) {
      case _BrandMode.icon:
        child = _locker(iconHeight);
      case _BrandMode.wordmark:
        child = _title(titleHeight);
      case _BrandMode.stacked:
        child = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _locker(iconHeight),
            SizedBox(height: spacing),
            _title(titleHeight),
          ],
        );
      case _BrandMode.full:
        if (narrow) {
          child = _locker(iconHeight);
        } else {
          child = Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: alignment,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _locker(iconHeight),
              SizedBox(width: spacing),
              Flexible(child: _title(titleHeight)),
            ],
          );
        }
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

  Widget _title(double height) {
    return Image.asset(
      BrandAssets.title,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Text(
        'Need For Needs',
        style: TextStyle(
          fontSize: height * 0.55,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _BrandMode { full, icon, wordmark, stacked }
