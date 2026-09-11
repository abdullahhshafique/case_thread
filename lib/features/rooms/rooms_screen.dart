import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../auth/auth_providers.dart';
import '../profiles/profiles_repository.dart';

/// Authenticated home: lists the user's case rooms. Sprint 0 ships the
/// shell with an empty state; room CRUD arrives in Sprint 3 (ExecutionPlan.md §3).
class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Profile name from the `profiles` table (Sprint 2 wiring), with the
    // auth metadata name as fallback while it loads.
    final authName = ref.watch(sessionProvider).value?.displayName ?? '';
    final profile = ref.watch(myProfileProvider).value;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your case rooms'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Text(
                profile?.displayName ?? authName,
                style: text.bodyMedium?.copyWith(
                  color: text.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.4),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No case rooms yet',
                style: text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Creating a room takes under a minute — it arrives in the '
                'next build milestone.',
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
