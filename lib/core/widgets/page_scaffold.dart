import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Shared page scaffold with optional back affordance and actions.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showBack = true,
    this.bottom,
    this.padding = const EdgeInsets.all(20),
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBack;
  final Widget? bottom;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: showBack,
        actions: actions,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: bottom,
              ),
            ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Padding(
          key: ValueKey(title),
          padding: padding,
          child: body,
        ),
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: AppTextStyles.caption),
    );
  }
}
