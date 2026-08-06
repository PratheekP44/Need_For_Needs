import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../theme/app_colors.dart';
import '../utils/media_url.dart';
import 'image_placeholder.dart';

export '../utils/media_url.dart' show resolveMediaUrl;

/// Product thumbnail with disk/memory cache; falls back to placeholder.
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
        memCacheWidth: width != null && width!.isFinite ? (width! * 2).round() : 600,
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
        errorWidget: (_, _, _) => ImagePlaceholder(
          height: height,
          width: width,
          borderRadius: borderRadius,
          icon: icon,
          size: iconSize,
        ),
      ),
    );
  }
}
