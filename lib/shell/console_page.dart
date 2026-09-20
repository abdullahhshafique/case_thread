import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// v3 page shell for the standalone routes (templates / join / search):
/// console background, back affordance, and the v3 page header instead
/// of a Material AppBar. Body content keeps its own widgets and inherits
/// the canonical theme.
class ConsolePageScaffold extends StatelessWidget {
  const ConsolePageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.floatingActionButton,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.consoleBg,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 18, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back to cases',
                    icon: const Icon(Icons.arrow_back, size: 20),
                    color: AppColors.consoleMuted,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: text.headlineLarge?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: text.bodySmall?.copyWith(
                              color: AppColors.consoleMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.consoleBorder),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
