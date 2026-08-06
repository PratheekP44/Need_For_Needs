import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Maps technical exceptions to short, user-facing copy.
String userFacingError(Object error) {
  if (error is ApiException) {
    final msg = error.message.toLowerCase();
    // Only token/session failures are "Session expired".
    // Login credential failures are also 401 — keep the API message.
    if (error.statusCode == 401 &&
        (msg.contains('token') ||
            msg.contains('expired') ||
            msg.contains('session') ||
            msg.contains('revoked'))) {
      return 'Session expired. Please sign in again.';
    }
    if (msg.contains('socket') ||
        msg.contains('failed to fetch') ||
        msg.contains('network') ||
        msg.contains('connection')) {
      return 'Unable to connect. Please check your internet.';
    }
    // Purchase-flow copy only. Do NOT match bare "stock" / "available" /
    // "insufficient" — those appear in admin stocking, 404 routes, and RBAC.
    if (msg.contains('out of stock') ||
        msg.contains('unavailable for purchase') ||
        msg.contains('insufficient or unavailable stock') ||
        msg.contains('cart contains unavailable') ||
        msg.contains('stock is unavailable')) {
      return 'Out of stock or unavailable.';
    }
    if (msg.contains('payment')) return 'Payment failed. Please try again.';
    if (msg.contains('server') || error.statusCode == 502 || error.statusCode == 503) {
      return 'Server unavailable. Please try again later.';
    }
    if (msg.contains('image')) return 'Image unavailable.';
    if (error.statusCode == 404) {
      if (msg.contains('cart')) return error.message;
      if (msg.contains('route not found')) return error.message;
      return error.message;
    }
    return error.message;
  }
  final raw = error.toString().replaceFirst('Exception: ', '');
  final lower = raw.toLowerCase();
  if (lower.contains('failed to fetch') ||
      lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('offline')) {
    return 'Unable to connect. You appear to be offline.';
  }
  return raw;
}

void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

void showComingSoon(BuildContext context, [String feature = 'This feature']) {
  showAppSnackBar(context, '$feature is coming soon');
}

/// Centered empty-state used across cart, orders, home, admin.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
