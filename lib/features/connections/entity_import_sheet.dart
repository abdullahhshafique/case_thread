import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'connections_providers.dart';

/// Step 4 (Obsidian-templates import): pick a published template that
/// carries an `entity_seed` (0044), fill its {{placeholders}}, preview
/// the resolved entities/relationships, then materialize via the
/// `materialize_entity_seed` RPC (edit_case holders; audited server-side).
class EntityImportSheet extends ConsumerStatefulWidget {
  const EntityImportSheet({super.key, required this.roomId});

  final String roomId;

  static Future<void> show(BuildContext context, String roomId) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: EntityImportSheet(roomId: roomId),
      ),
    );
  }

  @override
  ConsumerState<EntityImportSheet> createState() => _EntityImportSheetState();
}

class _EntityImportSheetState extends ConsumerState<EntityImportSheet> {
  SeedTemplate? _selected;
  final Map<String, TextEditingController> _valueControllers = {};
  bool _importing = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _valueControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _select(SeedTemplate template) {
    setState(() {
      _selected = template;
      _error = null;
      for (final c in _valueControllers.values) {
        c.dispose();
      }
      _valueControllers.clear();
      for (final p in template.placeholders) {
        _valueControllers[p] = TextEditingController();
      }
    });
  }

  /// Resolved entity names with the current placeholder values.
  List<String> get _resolvedNames {
    final template = _selected;
    if (template == null) return const [];
    return [
      for (final e in template.entities)
        _resolve(e['name'] as String? ?? ''),
    ];
  }

  String _resolve(String raw) {
    var out = raw;
    for (final entry in _valueControllers.entries) {
      out = out.replaceAll('{{${entry.key}}}', entry.value.text.trim());
    }
    return out;
  }

  bool get _allFilled => _selected == null
      ? false
      : _resolvedNames.isNotEmpty &&
            _resolvedNames.every((n) => n.isNotEmpty && !n.contains('{{'));

  Future<void> _import() async {
    if (_importing || !_allFilled) return;
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(connectionsRepositoryProvider)
          .importEntitySeed(
            roomId: widget.roomId,
            templateId: _selected!.id,
            values: {
              for (final entry in _valueControllers.entries)
                entry.key: entry.value.text.trim(),
            },
          );
      ref.invalidate(entityMapProvider(widget.roomId));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created == 0
                ? 'Everything from that template was already in the map.'
                : 'Imported $created entit'
                    '${created == 1 ? 'y' : 'ies'} into the map.',
          ),
        ),
      );
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = toAppException(error).message);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(seedTemplatesProvider);
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Text(
            'Import entity template',
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Bring in a pre-structured cast of people, places and '
            'connections in one step.',
            style: text.bodySmall?.copyWith(color: AppColors.consoleMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          templates.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, _) => Text(
              'Could not load templates: $error',
              style: text.bodySmall?.copyWith(color: AppColors.stateError),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Text(
                  'No import templates published yet.',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.consoleMuted,
                  ),
                );
              }
              return Column(
                children: [
                  for (final template in list)
                    _TemplateTile(
                      key: Key('seed-template-${template.id}'),
                      template: template,
                      selected: _selected?.id == template.id,
                      onTap: () => _select(template),
                    ),
                ],
              );
            },
          ),
          // Placeholder fields + preview
          if (_selected != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'FILL IN',
              style: text.labelMedium?.copyWith(
                color: AppColors.consoleMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final placeholder in _selected!.placeholders)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TextField(
                  key: Key('seed-value-$placeholder'),
                  controller: _valueControllers[placeholder],
                  decoration: InputDecoration(
                    labelText: placeholder.replaceAll('_', ' '),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            // Preview: resolved names + relationship count
            Container(
              key: const Key('seed-preview'),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderSubtle),
                color: AppColors.bgSurfaceRaised,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PREVIEW',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.consoleMuted,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final name in _resolvedNames)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle_outlined,
                            size: 12,
                            color: AppColors.statusOpen,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              name.isEmpty ? '— needs a value —' : name,
                              style: text.bodySmall?.copyWith(
                                color: name.isEmpty
                                    ? AppColors.statePending
                                    : AppColors.consoleText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${_selected!.relationships.length} relationship'
                    '${_selected!.relationships.length == 1 ? '' : 's'} '
                    'will be linked automatically.',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.consoleMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _error!,
                  style: text.bodySmall?.copyWith(color: AppColors.stateError),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('seed-import'),
              onPressed: (_importing || !_allFilled) ? null : _import,
              child: _importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Import into map'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final SeedTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.brandBlue : AppColors.borderSubtle,
          ),
          color: selected
              ? AppColors.brandBlue.withValues(alpha: 0.08)
              : AppColors.bgSurfaceRaised,
        ),
        child: Row(
          children: [
            Icon(
              Icons.hub_outlined,
              size: 20,
              color: selected ? AppColors.brandBlue : AppColors.consoleMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.displayName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (template.description.isNotEmpty)
                    Text(
                      template.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.consoleMuted,
                      ),
                    ),
                  Text(
                    '${template.entities.length} entities · '
                    '${template.relationships.length} connections',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.consoleMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, size: 18, color: AppColors.brandBlue),
          ],
        ),
      ),
    );
  }
}
