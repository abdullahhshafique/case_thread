import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'connections_providers.dart';

/// Add-entity sheet (Connections tab, edit_case holders): name +
/// type chips + optional note. Mirrors the briefing-editor sheet
/// pattern — console surfaces, token-only colors, typed errors.
class EntityEditorSheet extends ConsumerStatefulWidget {
  const EntityEditorSheet({super.key, required this.roomId});

  final String roomId;

  static Future<void> show(BuildContext context, String roomId) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: EntityEditorSheet(roomId: roomId),
      ),
    );
  }

  @override
  ConsumerState<EntityEditorSheet> createState() => _EntityEditorSheetState();
}

class _EntityEditorSheetState extends ConsumerState<EntityEditorSheet> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'person';
  bool _saving = false;
  String? _error;

  static const _types = [
    ('person', 'Person', Icons.person_outline),
    ('location', 'Location', Icons.location_on_outlined),
    ('vehicle', 'Vehicle', Icons.directions_car_outlined),
    ('evidence', 'Evidence', Icons.description_outlined),
    ('org', 'Org', Icons.business_outlined),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final node = await ref
          .read(connectionsRepositoryProvider)
          .addEntity(
            roomId: widget.roomId,
            entityType: _type,
            name: name,
            note: _noteController.text.trim(),
          );
      ref.invalidate(entityMapProvider(widget.roomId));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${node.name}" added to the map.')),
      );
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = toAppException(error).message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add entity',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'A person, place, thing or organization in this case.',
              style: text.bodySmall?.copyWith(color: AppColors.consoleMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('entity-name-field'),
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Imran Shaikh, Dock 7 Warehouse',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'TYPE',
              style: text.labelMedium?.copyWith(
                color: AppColors.consoleMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final (type, label, icon) in _types)
                  ChoiceChip(
                    key: Key('entity-type-$type'),
                    avatar: Icon(
                      icon,
                      size: 15,
                      color: _type == type
                          ? AppColors.brandBlue
                          : AppColors.consoleMuted,
                    ),
                    label: Text(label),
                    selected: _type == type,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('entity-note-field'),
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. warehouse security guard on duty',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _error!,
                  style: text.bodySmall
                      ?.copyWith(color: AppColors.stateError),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('entity-save'),
              onPressed:
                  _saving || _nameController.text.trim().isEmpty
                      ? null
                      : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add to map'),
            ),
          ],
        ),
      ),
    );
  }
}
