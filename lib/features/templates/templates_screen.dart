import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../shell/console_page.dart';
import '../rooms/rooms_providers.dart' show activeCaseTypesProvider;
import 'template_editor_sheet.dart';
import 'templates.dart';

/// Template marketplace (Phase 4, Phases.md §5): browse published
/// templates, manage your drafts, design a custom case type (name +
/// roles + permission grid), and publish it — which materializes a
/// real case type available at room creation (0021).
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final published = ref.watch(publishedTemplatesProvider);
    final mine = ref.watch(myTemplatesProvider);
    final text = Theme.of(context).textTheme;

    return ConsolePageScaffold(
      title: 'Template marketplace',
      subtitle: 'Design a case type once — every team can use it',
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('templates-new'),
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New template'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Your drafts', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          mine.maybeWhen(
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      'No drafts yet — design a custom case type and share '
                      'it with everyone.',
                      style: text.bodyMedium,
                    ),
                  )
                : Column(
                    children: [
                      for (final t in list)
                        _DraftTile(
                          template: t,
                          onEdit: () => _openEditor(context, ref, existing: t),
                        ),
                    ],
                  ),
            orElse: () => const LinearProgressIndicator(),
          ),
          const Divider(height: AppSpacing.xxl),
          Text('Published by the community', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Published templates become selectable case types when '
            'creating a room.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          published.maybeWhen(
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      'Nothing published yet.',
                      style: text.bodyMedium,
                    ),
                  )
                : Column(
                    children: [
                      for (final t in list) _PublishedTile(template: t),
                    ],
                  ),
            orElse: () => const LinearProgressIndicator(),
          ),
        ],
      ),
    );
  }

  void _openEditor(
    BuildContext context,
    WidgetRef ref, {
    CaseTypeTemplate? existing,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TemplateEditorSheet(existing: existing),
    );
  }
}

class _DraftTile extends ConsumerWidget {
  const _DraftTile({required this.template, required this.onEdit});

  final CaseTypeTemplate template;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Card(
      key: Key('template-draft-${template.slug}'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: ListTile(
        title: Text(template.displayName),
        subtitle: Text(
          '${template.roles.length} roles · '
          '${template.isPublished ? 'published' : 'draft'}',
          style: text.bodySmall,
        ),
        trailing: template.isPublished
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit draft',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    key: Key('template-publish-${template.slug}'),
                    tooltip: 'Publish to marketplace',
                    onPressed: () => _publish(context, ref),
                    icon: const Icon(Icons.publish_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete draft',
                    onPressed: () => _delete(context, ref),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    try {
      final caseTypeId = await ref
          .read(templateRepositoryProvider)
          .publishTemplate(template.id);
      ref.invalidate(myTemplatesProvider);
      ref.invalidate(publishedTemplatesProvider);
      // A new case_types row now exists — room creation must see it.
      ref.invalidate(activeCaseTypesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${template.displayName}" published — rooms can now use '
              '"$caseTypeId".',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(templateRepositoryProvider).deleteTemplate(template.id);
      ref.invalidate(myTemplatesProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _PublishedTile extends StatelessWidget {
  const _PublishedTile({required this.template});

  final CaseTypeTemplate template;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      key: Key('template-published-${template.slug}'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: Text(template.displayName),
        subtitle: Text(
          '${template.roles.length} roles · ${template.description}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall,
        ),
        trailing: const Icon(
          Icons.check_circle_outline,
          color: Color(0xFF5FBF7A),
        ),
      ),
    );
  }
}
