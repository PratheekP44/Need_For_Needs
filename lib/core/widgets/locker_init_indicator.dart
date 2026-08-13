import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Subtle 2×2 locker-compartment pulse for splash / init.
///
/// Cycles one active cell at a time — calm, not playful.
class LockerInitIndicator extends StatefulWidget {
  const LockerInitIndicator({
    super.key,
    this.size = 28,
    this.gap = 5,
    this.period = const Duration(milliseconds: 520),
  });

  final double size;
  final double gap;
  final Duration period;

  @override
  State<LockerInitIndicator> createState() => _LockerInitIndicatorState();
}

class _LockerInitIndicatorState extends State<LockerInitIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.period * 4,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant LockerInitIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period * 4;
      if (!_controller.isAnimating) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cell = (widget.size - widget.gap) / 2;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // 0..3 across TL → TR → BL → BR
        final active = (_controller.value * 4).floor() % 4;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Column(
            children: [
              Row(
                children: [
                  _cell(cell, active == 0),
                  SizedBox(width: widget.gap),
                  _cell(cell, active == 1),
                ],
              ),
              SizedBox(height: widget.gap),
              Row(
                children: [
                  _cell(cell, active == 2),
                  SizedBox(width: widget.gap),
                  _cell(cell, active == 3),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(double side, bool on) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: on
            ? AppColors.warmGray
            : AppColors.secondaryDark.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(side * 0.28),
      ),
    );
  }
}
