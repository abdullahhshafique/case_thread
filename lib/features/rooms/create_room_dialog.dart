import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_spacing.dart';
import 'data/supabase_rooms_repository.dart' show roomsRepositoryProvider;
import 'domain/rooms_repository.dart';
import 'rooms_providers.dart';

/// Room creation (PRD §6.1): name + case type → server generates the
/// code → shown ONCE to the owner.
Future<void> showCreateRoomDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const CreateRoomDialog(),
  );
}

class CreateRoomDialog extends ConsumerStatefulWidget {
  const CreateRoomDialog({super.key});

  @override
  ConsumerState<CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends ConsumerState<CreateRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  String? _selectedCaseType;
  bool _submitting = false;
  String? _error;
  CreatedRoom? _created;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caseTypes = ref.watch(activeCaseTypesProvider);
    final text = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(_created == null ? 'New case room' : 'Room created'),
      content: _created != null ? _successBody(text) : _formBody(caseTypes),
      actions: _created == null
          ? [_closeButton(), _createButton()]
          : [_doneButton()],
    );
  }

  Widget _formBody(AsyncValue<List<CaseType>> caseTypes) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('create-room-name'),
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Room name',
              hintText: 'e.g. Contract dispute — Q3',
            ),
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.isEmpty) return 'Give the room a name.';
              if (name.length > 120) {
                return 'Keep the name under 120 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          switch (caseTypes) {
            AsyncData(:final value) => DropdownButtonFormField<String>(
              key: const Key('create-room-type'),
              initialValue: _selectedCaseType,
              decoration: const InputDecoration(labelText: 'Case type'),
              items: value
                  .map(
                    (ct) => DropdownMenuItem(
                      value: ct.id,
                      child: Text(ct.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (id) => setState(() => _selectedCaseType = id),
              validator: (value) => value == null ? 'Pick a case type.' : null,
            ),
            AsyncError(:final error) => Text(
              toAppException(error).message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            _ => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(),
            ),
          },
          TextFormField(
            key: const Key('create-room-code'),
            controller: _codeController,
            maxLength: 16,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Access code (optional)',
              hintText: 'Leave empty to auto-generate · e.g. ROBBERY2',
              counterText: '',
            ),
            validator: (value) {
              // Mirrors the server rule (0037): 6–16 chars from the same
              // unambiguous alphabet generate_access_code() uses; the
              // server normalizes to uppercase.
              final code = value?.trim() ?? '';
              if (code.isEmpty) return null;
              if (!RegExp(r'^[A-HJ-NP-Za-hj-np-z2-9]{6,16}$').hasMatch(code)) {
                return '6–16 characters: A–Z (no I/O) and digits 2–9.';
              }
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _successBody(TextTheme text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Share this code with the people you want in the room. '
          'You can rotate it anytime.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.primary),
          ),
          child: Text(
            // Monospace: exact character distinction matters (Design.md §2).
            _created!.accessCode,
            key: const Key('create-room-code'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 28,
              fontWeight: FontWeight.w500,
              letterSpacing: 6,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'This code is shown only once — copy it now.',
          style: text.bodyMedium?.copyWith(
            color: text.bodyMedium?.color?.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _closeButton() => TextButton(
    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
    child: const Text('Cancel'),
  );

  Widget _createButton() => ElevatedButton(
    key: const Key('create-room-submit'),
    onPressed: _submitting ? null : _submit,
    child: _submitting
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text('Create'),
  );

  Widget _doneButton() => ElevatedButton(
    onPressed: () => Navigator.of(context).pop(_created),
    child: const Text('Done'),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(roomsRepositoryProvider)
          .createRoom(
            name: _nameController.text.trim(),
            caseTypeId: _selectedCaseType!,
            accessCode: _codeController.text.trim().isEmpty
                ? null
                : _codeController.text.trim(),
          );
      setState(() => _created = created);
    } on Exception catch (error) {
      // Dev posture: show the mapped message AND the raw cause so a
      // failure screenshot is diagnosable without the console.
      setState(() => _error = '${toAppException(error).message}\n— $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
