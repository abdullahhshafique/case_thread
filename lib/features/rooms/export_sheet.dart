import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'export_pdf.dart';
import 'export_report.dart';

/// Phase 3 (export overhaul): bottom-sheet export menu replacing the
/// old copy-only AppBar action. Options: Markdown (copy to clipboard)
/// and PDF (save/share via the OS sheet — a download on web).
class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({super.key, required this.roomId, required this.report});

  final String roomId;
  final CaseReport report;

  /// Fetches the report, then presents the export options sheet.
  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    String roomId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final CaseReport report;
    try {
      report = await ref.read(exportRepositoryProvider).exportRoom(roomId);
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(toAppException(error).message)),
      );
      return;
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ExportSheet(roomId: roomId, report: report),
    );
  }

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(toAppException(error).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Export case report',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ExportOption(
              key: const Key('export-option-pdf'),
              icon: Icons.picture_as_pdf_outlined,
              title: 'PDF report',
              subtitle: 'Formatted case file — save, share or print',
              busy: _busy,
              onTap: () => _run(() async {
                final bytes = await widget.report.toPdfBytes();
                await Printing.sharePdf(
                  bytes: Uint8List.fromList(bytes),
                  filename:
                      'case-report-${widget.roomId.substring(0, 4)}.pdf',
                );
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ExportOption(
              key: const Key('export-option-markdown'),
              icon: Icons.copy_rounded,
              title: 'Markdown (copy)',
              subtitle: 'Plain text — paste anywhere to file it',
              busy: _busy,
              onTap: () {
                final messenger = ScaffoldMessenger.of(context);
                _run(() async {
                  await Clipboard.setData(
                    ClipboardData(text: widget.report.toMarkdown()),
                  );
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Markdown report copied.')),
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
          color: AppColors.bgSurfaceRaised,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.brandBlue),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.consoleMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.chevron_right, size: 20, color: AppColors.consoleMuted),
          ],
        ),
      ),
    );
  }
}
