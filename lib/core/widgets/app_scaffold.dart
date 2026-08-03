import 'package:flutter/material.dart';

/// Shared scaffold placeholder used by feature screens during architecture setup.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    this.body,
  });

  final String title;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body ??
          Center(
            child: Text(
              '$title placeholder',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
    );
  }
}
