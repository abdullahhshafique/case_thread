import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import 'templates.dart';

/// Draft editor (Phase 4): name/description/id, the role set, and the
/// per-role permission grid. Saves as a PRIVATE draft; publishing is
/// a separate explicit action (0021's publish_template validates
/// everything server-side).
class TemplateEditorSheet extends ConsumerStatefulWidget {
  const TemplateEditorSheet({super.key, this.existing});

  final CaseTypeTemplate? existing;

  @override
  ConsumerState<TemplateEditorSheet> createState() =>
      _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends ConsumerState<TemplateEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _description;
  late List<TemplateRole> _roles;
  late String _ownerRoleSlug;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _name = TextEditingController(text: t?.displayName ?? '');
    _slug = TextEditingController(text: t?.slug ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _roles = t != null
        ? [for (final r in t.roles) _copyRole(r)]
        : [TemplateRole.leadDefault('lead', 'Lead'), _contributorDefault()];
    _ownerRoleSlug = t?.ownerRoleSlug ?? 'lead';
  }

  static TemplateRole _copyRole(TemplateRole r) => TemplateRole(
    slug: r.slug,
    displayName: r.displayName,
    isLeadTier: r.isLeadTier,
    permissions: Map.of(r.permissions),
  );

  static TemplateRole _contributorDefault() => const TemplateRole(
    slug: 'member',
    displayName: 'Member',
    isLeadTier: false,
    permissions: {
      'view_case': true,
      'edit_case': true,
      'upload_evidence': true,
      'comment': true,
      'approve_ai_findings': false,
      'manage_members': false,
      'export_reports': false,
      'view_privileged': false,
    },
  );

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        // The roles grid grows with content — scroll instead of overflow.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'New template' : 'Edit template',
                style: text.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('tpl-name'),
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Template name',
                  hintText: 'e.g. Journalism Room',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name it.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('tpl-slug'),
                controller: _slug,
                enabled: widget.existing?.isPublished != true,
                decoration: const InputDecoration(
                  labelText: 'Template id',
                  hintText: 'lowercase_letters_underscores (3-31)',
                  helperText: 'Becomes the case type id when published.',
                ),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (!RegExp(r'^[a-z][a-z0-9_]{2,30}$').hasMatch(s)) {
                    return '3-31 chars: lowercase first, then letters/digits/underscores.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('tpl-description'),
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Roles & permissions', style: text.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              for (var i = 0; i < _roles.length; i++)
                _RoleEditor(
                  role: _roles[i],
                  isOwnerRole: _roles[i].slug == _ownerRoleSlug,
                  canDelete: _roles.length > 1,
                  onChanged: (role) => setState(() {
                    if (_ownerRoleSlug == _roles[i].slug &&
                        role.slug != _roles[i].slug) {
                      _ownerRoleSlug = role.slug;
                    }
                    _roles[i] = role;
                  }),
                  onOwnerChanged: (slug) =>
                      setState(() => _ownerRoleSlug = slug),
                  onDelete: () => setState(() {
                    if (_ownerRoleSlug == _roles[i].slug && _roles.length > 1) {
                      _ownerRoleSlug = _roles
                          .firstWhere((r) => r != _roles[i])
                          .slug;
                    }
                    _roles.removeAt(i);
                  }),
                ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('tpl-add-role'),
                onPressed: _roles.length >= 8
                    ? null
                    : () => setState(() => _roles.add(_contributorDefault())),
                icon: const Icon(Icons.add, size: 18),
                label: Text(_roles.length >= 8 ? 'Max 8 roles' : 'Add role'),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('tpl-save'),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save draft'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_roles.any((r) => r.slug == _ownerRoleSlug)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The owner role must be one of your roles.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(templateRepositoryProvider)
          .saveTemplate(
            slug: _slug.text.trim(),
            displayName: _name.text.trim(),
            description: _description.text.trim(),
            ownerRoleSlug: _ownerRoleSlug,
            roles: _roles,
          );
      ref.invalidate(myTemplatesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

/// The 8 permission keys + human labels — shared by the editor and
/// the role card (values map 1:1 to the roles grid, 0004).
const Map<String, String> _permLabels = {
  'view_case': 'View case',
  'edit_case': 'Edit case',
  'upload_evidence': 'Upload evidence',
  'comment': 'Comment',
  'approve_ai_findings': 'Approve AI findings',
  'manage_members': 'Manage members',
  'export_reports': 'Export reports',
  'view_privileged': 'View privileged fields',
};

/// One role + its 8-toggle permission grid, with lead-tier and
/// owner-role selection.
class _RoleEditor extends StatelessWidget {
  const _RoleEditor({
    required this.role,
    required this.isOwnerRole,
    required this.canDelete,
    required this.onChanged,
    required this.onOwnerChanged,
    required this.onDelete,
  });

  final TemplateRole role;
  final bool isOwnerRole;
  final bool canDelete;
  final ValueChanged<TemplateRole> onChanged;
  final ValueChanged<String> onOwnerChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      key: Key('tpl-role-${role.slug}'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: Key('tpl-role-name-${role.slug}'),
                    initialValue: role.displayName,
                    decoration: const InputDecoration(
                      labelText: 'Role name',
                      isDense: true,
                    ),
                    onChanged: (v) => onChanged(_with(displayName: v)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (canDelete)
                  IconButton(
                    tooltip: 'Remove role',
                    onPressed: onDelete,
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                FilterChip(
                  key: Key('tpl-role-lead-${role.slug}'),
                  label: const Text('Lead tier'),
                  selected: role.isLeadTier,
                  onSelected: (v) => onChanged(_with(isLeadTier: v)),
                ),
                FilterChip(
                  key: Key('tpl-role-owner-${role.slug}'),
                  label: const Text('Room owner role'),
                  selected: isOwnerRole,
                  onSelected: (v) {
                    if (v) onOwnerChanged(role.slug);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // view_case is always true (server invariant, 0021) —
            // shown as locked rather than hidden so the model is
            // visible to the designer.
            _Toggle(
              label: _permLabels['view_case']!,
              value: true,
              locked: true,
              onChanged: (_) {},
            ),
            for (final entry in _permLabels.entries)
              if (entry.key != 'view_case')
                _Toggle(
                  label: entry.value,
                  value: role.permissions[entry.key] ?? false,
                  onChanged: (v) => onChanged(
                    _with(permissions: {...role.permissions, entry.key: v}),
                  ),
                ),
            Text(
              'id: ${role.slug}',
              style: text.bodySmall?.copyWith(
                color: text.bodySmall?.color?.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TemplateRole _with({
    String? displayName,
    bool? isLeadTier,
    Map<String, bool>? permissions,
  }) => TemplateRole(
    slug: role.slug,
    displayName: displayName ?? role.displayName,
    isLeadTier: isLeadTier ?? role.isLeadTier,
    permissions: permissions ?? role.permissions,
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.locked = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: Key('tpl-perm-${label.replaceAll(' ', '-')}'),
      title: Text(label),
      value: value,
      onChanged: locked ? null : onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
