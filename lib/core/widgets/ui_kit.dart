import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/money_format.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: AppTextStyles.title),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: AppTextStyles.label,
            ),
          ),
      ],
    );
  }
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.hint = 'Search',
    this.onTap,
    this.onChanged,
    this.onFilterPressed,
    this.readOnly = false,
    this.controller,
  });

  final String hint;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterPressed;
  final bool readOnly;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
        suffixIcon: IconButton(
          tooltip: 'Filters',
          onPressed: onFilterPressed,
          icon: Icon(
            Icons.tune_rounded,
            color: onFilterPressed == null ? AppColors.muted.withValues(alpha: 0.5) : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          )
        : icon == null
            ? Text(label)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              );

    final button = FilledButton(
      onPressed: enabled ? onPressed : null,
      child: child,
    );

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      child: Text(label),
    );
    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class QuantitySelector extends StatelessWidget {
  const QuantitySelector({
    super.key,
    required this.quantity,
    this.onIncrement,
    this.onDecrement,
  });

  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          Text(
            '$quantity',
            style: AppTextStyles.label.copyWith(color: AppColors.onBackground),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.useBrandGradient = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// Admin dashboard statistic cards use primary → secondary gradient.
  final bool useBrandGradient;

  @override
  Widget build(BuildContext context) {
    final onGradient = AppColors.onPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: useBrandGradient ? null : AppColors.surface,
        gradient: useBrandGradient ? AppColors.brandLinearGradient : null,
        borderRadius: BorderRadius.circular(16),
        border: useBrandGradient ? null : Border.all(color: AppColors.border),
        boxShadow: useBrandGradient
            ? const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: useBrandGradient
                  ? onGradient.withValues(alpha: 0.18)
                  : color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: useBrandGradient ? onGradient : color,
              size: 20,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: AppTextStyles.title.copyWith(
              color: useBrandGradient ? onGradient : AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: useBrandGradient
                  ? onGradient.withValues(alpha: 0.9)
                  : AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class PriceText extends StatelessWidget {
  const PriceText(this.amount, {super.key, this.style});

  final double amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      MoneyFormat.format(amount),
      style: style ??
          AppTextStyles.title.copyWith(
            color: AppColors.primary,
            fontSize: 16,
          ),
    );
  }
}
