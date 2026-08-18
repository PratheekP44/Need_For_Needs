import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/order_display.dart';

/// Subtle proximity tip shown on Collect (one tasteful line).
const String collectProximityTip =
    'Stay near the locker — Bluetooth works better nearby.';

/// Compact locker face: cells 1…N, only [highlight] boxes emphasized.
///
/// [boxNumbers] must be the same list used for the unlock Port bitmap.
class CollectBoxGrid extends StatelessWidget {
  const CollectBoxGrid({
    super.key,
    required this.boxNumbers,
    this.columns = 2,
  });

  final List<int> boxNumbers;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final highlight = boxNumbers.toSet();
    if (highlight.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = highlight.toList()..sort();
    final maxBox = sorted.last;
    // Compact face covering this order's range (never force 32).
    final cellCount = maxBox.clamp(1, 16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          sorted.length == 1 ? 'Box opening' : 'Boxes opening',
          style: AppTextStyles.label.copyWith(
            fontSize: 14,
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: sorted
              .map(
                (n) => Container(
                  constraints:
                      const BoxConstraints(minWidth: 60, minHeight: 52),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    formatBoxLabel(n),
                    style: AppTextStyles.title.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cream,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        if (cellCount > 1 && cellCount <= 12) ...[
          const SizedBox(height: 14),
          Text(
            'Your locker',
            style: AppTextStyles.caption.copyWith(
              fontSize: 13,
              color: AppColors.muted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final gap = 6.0;
              final colW =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: gap,
                runSpacing: gap,
                children: List.generate(cellCount, (i) {
                  final n = i + 1;
                  final on = highlight.contains(n);
                  return SizedBox(
                    width: colW,
                    height: 38,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: on
                            ? AppColors.primaryDark
                            : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: on
                              ? AppColors.primaryDark
                              : AppColors.border.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          formatBoxLabel(n),
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 13,
                            color: on ? AppColors.cream : AppColors.muted,
                            fontWeight:
                                on ? FontWeight.w700 : FontWeight.w500,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Short locked → unlocking → open motion for Collect success.
class LockerOpenSuccessMark extends StatefulWidget {
  const LockerOpenSuccessMark({super.key});

  @override
  State<LockerOpenSuccessMark> createState() => _LockerOpenSuccessMarkState();
}

class _LockerOpenSuccessMarkState extends State<LockerOpenSuccessMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _door;
  late final Animation<double> _check;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _door = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.55, curve: Curves.easeOutCubic),
    );
    _check = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      width: 88,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final open = _door.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(18 * open, 0),
                child: Opacity(
                  opacity: (1 - open * 0.85).clamp(0.0, 1.0),
                  child: Container(
                    width: 32,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: AppColors.cream.withValues(alpha: 1 - open),
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: _check.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.7 + 0.3 * _check.value,
                  child: const Icon(
                    Icons.check_rounded,
                    size: 38,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
