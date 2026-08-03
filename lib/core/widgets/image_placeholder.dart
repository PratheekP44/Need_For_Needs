import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Soft image/icon placeholder used across product and locker cards.
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({
    super.key,
    this.icon = Icons.inventory_2_outlined,
    this.size = 48,
    this.borderRadius = 14,
    this.height,
    this.width,
  });

  final IconData icon;
  final double size;
  final double borderRadius;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceMuted, AppColors.chip],
        ),
      ),
      child: Center(
        child: Icon(icon, size: size, color: AppColors.primaryLight),
      ),
    );
  }
}
