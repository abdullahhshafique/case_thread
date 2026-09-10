import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Shown when no Supabase configuration is present (Sprint 0 state and any
/// fresh clone without `.env`). Calm, factual instructions per Design.md §9
/// — no marketing voice inside the working product.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CaseThread', style: text.headlineLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'The app isn\'t connected to a backend yet.',
                  style: text.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'To connect a Supabase project:',
                  style: text.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                _step(
                  context,
                  '1',
                  'Create a project at supabase.com (free tier works).',
                ),
                _step(
                  context,
                  '2',
                  'Copy the project URL and anon key from Project Settings → API.',
                ),
                _step(
                  context,
                  '3',
                  'For mobile/desktop: create a .env file in the project root '
                      '(copy .env.example) and fill in SUPABASE_URL and '
                      'SUPABASE_ANON_KEY.',
                ),
                _step(
                  context,
                  '4',
                  'For web builds: pass the same values via '
                      '--dart-define (see README.md).',
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'The anon key is safe to ship in the client — access '
                  'control is enforced by Row Level Security on the '
                  'database, not by hiding the key.',
                  style: text.bodyMedium?.copyWith(
                    color: text.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _step(BuildContext context, String number, String body) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              number,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(body, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
