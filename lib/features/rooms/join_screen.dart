import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_spacing.dart';
import 'data/supabase_rooms_repository.dart' show roomsRepositoryProvider;
import 'domain/rooms_repository.dart';
import 'rooms_providers.dart';

/// Join flow (PRD §6.2): enter code → see room preview → pick a role →
/// pending until owner approves.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _codeController = TextEditingController();
  String? _error;
  bool _busy = false;

  RoomPreview? _roomPreview;
  RoleDefinition? _selectedRole;
  String? _resultStatus;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Join a case room')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_resultStatus != null)
                  ..._resultPane(text)
                else if (_roomPreview != null)
                  ..._rolePane(text)
                else
                  ..._codePane(text),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _codePane(TextTheme text) {
    return [
      Text('Enter the access code', style: text.headlineSmall),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Ask the room owner for the current 8-character code.',
        style: text.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.lg),
      TextField(
        key: const Key('join-code-field'),
        controller: _codeController,
        autofocus: true,
        maxLength: 8,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _previewRoom(),
        decoration: const InputDecoration(
          labelText: 'Access code',
          counterText: '',
          hintText: 'e.g. AB23CD45',
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(
          _error!,
          key: const Key('join-error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      ElevatedButton(
        key: const Key('join-preview-submit'),
        onPressed: _busy ? null : _previewRoom,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Continue'),
      ),
    ];
  }

  List<Widget> _rolePane(TextTheme text) {
    final roles = ref.watch(rolesForCaseTypeProvider(_roomPreview!.caseTypeId));
    return [
      Text(_roomPreview!.name, style: text.headlineMedium),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Pick the role you\'ll have in this room. The owner reviews your '
        'request before you can see case material.',
        style: text.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.lg),
      switch (roles) {
        AsyncData(:final value) => Column(
          children: [
            for (final role in value)
              RadioGroup<String>(
                groupValue: _selectedRole?.id,
                onChanged: (id) => setState(
                  () => _selectedRole = value.firstWhere((r) => r.id == id),
                ),
                child: RadioListTile<String>(
                  key: Key('join-role-${role.id}'),
                  value: role.id,
                  title: Text(role.displayName),
                ),
              ),
          ],
        ),
        AsyncError(:final error) => Text(
          toAppException(error).message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        _ => const CircularProgressIndicator(),
      },
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      ElevatedButton(
        key: const Key('join-submit'),
        onPressed: (_selectedRole == null || _busy) ? null : _join,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Request to join'),
      ),
      const SizedBox(height: AppSpacing.xs),
      TextButton(
        onPressed: () => setState(() {
          _roomPreview = null;
          _selectedRole = null;
          _error = null;
        }),
        child: const Text('Use a different code'),
      ),
    ];
  }

  List<Widget> _resultPane(TextTheme text) {
    final approved = _resultStatus == 'approved';
    return [
      Icon(
        approved ? Icons.check_circle_outline : Icons.hourglass_top_outlined,
        size: 64,
        color: approved
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        approved
            ? 'You\'re already a member of this room.'
            : 'Request sent. The owner will review it.',
        style: text.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        approved
            ? 'Opening the room…'
            : 'You\'ll see the room in your list once approved.',
        style: text.bodyMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.lg),
      ElevatedButton(
        onPressed: () {
          ref.read(roomsProvider.notifier).refresh();
          Navigator.of(context).pop();
        },
        child: const Text('Back to my rooms'),
      ),
    ];
  }

  Future<void> _previewRoom() async {
    final code = _codeController.text.trim();
    if (code.length != 8) {
      setState(() => _error = 'Codes are 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await ref
          .read(roomsRepositoryProvider)
          .previewRoomByCode(code);
      setState(() => _roomPreview = preview);
    } on AppException catch (error) {
      // Invalid code: same message whether it never existed (PRD §6.2).
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(roomsRepositoryProvider)
          .requestJoin(_codeController.text.trim(), _selectedRole!.id);
      setState(() => _resultStatus = result.status);
      ref.read(roomsProvider.notifier).refresh();
    } on AppException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
