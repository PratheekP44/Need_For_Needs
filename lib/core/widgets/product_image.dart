import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../theme/app_colors.dart';
import '../utils/media_url.dart';
import '../utils/product_image_url.dart';
import 'image_placeholder.dart';

export '../utils/media_url.dart' show resolveMediaUrl;

/// Product thumbnail with disk/memory cache; falls back to placeholder.
///
/// Cache is performance-only. Source of truth is the network [imageUrl]
/// from MongoDB / the API.
class ProductImage extends ConsumerWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.borderRadius = 14,
    this.icon = Icons.shopping_bag_outlined,
    this.iconSize = 36,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final double? height;
  final double? width;
  final double borderRadius;
  final IconData icon;
  final double iconSize;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseUrl = ref.watch(envConfigProvider).baseUrl;
    final url = resolveMediaUrl(imageUrl, apiBaseUrl: baseUrl);
    if (url.isEmpty) {
      return ImagePlaceholder(
        height: height,
        width: width,
        borderRadius: borderRadius,
        icon: icon,
        size: iconSize,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: width,
        fit: fit,
        memCacheWidth:
            width != null && width!.isFinite ? (width! * 2).round() : 600,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, _) => Container(
          height: height,
          width: width,
          color: AppColors.surfaceMuted,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, failedUrl, error) {
          ProductImageUrlRules.debugLogLoadFailure(failedUrl, error);
          final compact = (height ?? 0) > 0 && (height ?? 0) < 72;
          return Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: compact ? iconSize * 0.7 : iconSize,
                  color: AppColors.warmGray,
                ),
                if (!compact) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Image unavailable',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.warmGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
