import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_spacing.dart';
import 'data/supabase_rooms_repository.dart' show roomsRepositoryProvider;
import 'rooms_providers.dart' show roomsProvider;

/// Phase 6: briefing editor — a multiline sheet that writes
/// case_rooms.briefing (edit_case holders; the UPDATE policy enforces
/// the permission server-side). Reached from the Overview briefing
/// card's edit affordance.
class BriefingEditorSheet extends ConsumerStatefulWidget {
  const BriefingEditorSheet({
    super.key,
    required this.roomId,
    required this.initialBriefing,
  });

  final String roomId;
  final String? initialBriefing;

  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    String roomId,
    String? initialBriefing,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: BriefingEditorSheet(
          roomId: roomId,
          initialBriefing: initialBriefing,
        ),
      ),
    );
  }

  @override
  ConsumerState<BriefingEditorSheet> createState() =>
      _BriefingEditorSheetState();
}

class _BriefingEditorSheetState extends ConsumerState<BriefingEditorSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialBriefing ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(roomsRepositoryProvider)
          .updateBriefing(widget.roomId, _controller.text.trim());
      ref.invalidate(roomsProvider);
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(toAppException(error).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Case briefing',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Shared with every member of this room.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('briefing-input'),
              controller: _controller,
              maxLines: 6,
              minLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText:
                    'What is this case about? Key facts, the window of '
                    'interest, who does what…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('briefing-save'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save briefing'),
            ),
          ],
        ),
      ),
    );
  }
}
