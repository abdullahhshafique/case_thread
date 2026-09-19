import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'data/supabase_evidence_repository.dart' show evidenceRepositoryProvider;
import 'domain/evidence_repository.dart';
import 'domain/evidence_upload.dart';
import '../../core/api/models.dart' show Permission;
import 'room_permissions.dart';
import 'vault_providers.dart';

/// Evidence vault pane (Sprint 4): list + upload, permission-aware
/// error surfacing (PRD §6.7 — role-specific messages, never raw 403).
class VaultPane extends ConsumerWidget {
  const VaultPane({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vaultProvider(roomId));
    final progress = ref.watch(uploadProgressProvider(roomId));
    final canUpload = ref
        .watch(myRoomPermissionsProvider(roomId))
        .maybeWhen(
          data: (p) => p.can(Permission.uploadEvidence),
          orElse: () => false,
        );

    return Scaffold(
      backgroundColor: Colors.transparent,
      // UI hides what RLS would refuse (Architecture.md §2). The DB
      // still denies if this gate is somehow wrong.
      floatingActionButton: canUpload
          ? FloatingActionButton.extended(
              key: const Key('vault-upload'),
              onPressed: progress == null
                  ? () => _pickAndUpload(context, ref)
                  : null,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload evidence'),
            )
          : null,
      body: Stack(
        children: [
          state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorPane(
              message: error.toString(),
              onRetry: () => ref.invalidate(vaultProvider(roomId)),
            ),
            data: (vault) => switch (vault) {
              VaultError(:final message) => _ErrorPane(
                message: message,
                onRetry: () => ref.invalidate(vaultProvider(roomId)),
              ),
              VaultLoaded(:final entries) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(vaultProvider(roomId));
                  // Wait for the reload to finish so the spinner behaves.
                  await ref.read(vaultProvider(roomId).future);
                },
                child: entries.isEmpty
                    ? ListView(
                        // scrollable for RefreshIndicator
                        children: const [SizedBox(height: 120), _EmptyVault()],
                      )
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) =>
                            _EvidenceTile(entry: entries[index]),
                      ),
              ),
            },
          ),
          if (progress != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _UploadBar(progress: progress),
            ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles();
    if (picked.isEmpty) return;
    final platformFile = picked.single;

    try {
      final fileBytes = await platformFile.xFile.readAsBytes();
      final prepared = EvidenceValidator.prepareFromBytes(
        fileName: platformFile.name,
        mimeType: _fallbackMime(platformFile.name),
        bytes: fileBytes,
      );
      ref
          .read(uploadProgressProvider(roomId).notifier)
          .update(UploadProgress(fileName: prepared.fileName, progress: 0.1));
      await ref
          .read(evidenceRepositoryProvider)
          .upload(
            roomId: roomId,
            file: prepared,
            onProgress: (p) => ref
                .read(uploadProgressProvider(roomId).notifier)
                .update(
                  UploadProgress(fileName: prepared.fileName, progress: p),
                ),
          );
      ref.read(uploadProgressProvider(roomId).notifier).update(null);
      ref.invalidate(vaultProvider(roomId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded "${prepared.fileName}" to the vault.'),
          ),
        );
      }
    } on AppException catch (error) {
      ref.read(uploadProgressProvider(roomId).notifier).update(null);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  static String _fallbackMime(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    return switch (ext) {
      'pdf' => 'application/pdf',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'doc' => 'application/msword',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'txt' => 'text/plain',
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      _ => 'application/octet-stream',
    };
  }
}

class _EvidenceTile extends ConsumerWidget {
  const _EvidenceTile({required this.entry});

  final VaultEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final isImage = entry.mimeType.startsWith('image/');

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: ListTile(
        key: Key('vault-entry-${entry.id}'),
        leading: Icon(
          isImage
              ? Icons.image_outlined
              : entry.mimeType.startsWith('audio/')
              ? Icons.audio_file_outlined
              : Icons.description_outlined,
        ),
        title: Row(
          children: [
            Expanded(child: Text(entry.displayName, style: text.bodyLarge)),
            if (entry.classification != null)
              _VaultClassificationBadge(classification: entry.classification!),
          ],
        ),
        subtitle: Text(
          '${_formatSize(entry.sizeBytes)} · '
                  '${entry.uploaderName ?? 'Member'} · '
                  '${entry.uploadedAt.toLocal()}'
              .substring(0, 60),
          style: text.bodyMedium?.copyWith(
            color: text.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        trailing: IconButton(
          tooltip: 'Download',
          icon: const Icon(Icons.download_outlined),
          onPressed: () => _download(context, ref),
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    try {
      final url = await ref.read(evidenceRepositoryProvider).downloadUrl(entry);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download link ready (10 minutes): $url')),
        );
      }
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  static String _formatSize(int bytes) {
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}

class _EmptyVault extends StatelessWidget {
  const _EmptyVault();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.folder_open_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('No evidence yet', style: text.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Upload your first document to get started.',
          style: text.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, style: text.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _UploadBar extends StatelessWidget {
  const _UploadBar({required this.progress});

  final UploadProgress progress;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Uploading "${progress.fileName}"…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            LinearProgressIndicator(value: progress.progress),
          ],
        ),
      ),
    );
  }
}

/// Fact/Claim/Finding/Unknown badge (Phase 6, doc §7) — label +
/// outline color, never color alone (Design.md §1).
class _VaultClassificationBadge extends StatelessWidget {
  const _VaultClassificationBadge({required this.classification});

  final String classification;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (classification) {
      'fact' => (AppColors.stateSuccess, 'Fact'),
      'claim' => (AppColors.statePending, 'Claim'),
      'finding' => (AppColors.statusOpen, 'Finding'),
      'unknown' => (AppColors.statusNeutral, 'Unknown'),
      _ => (AppColors.statusNeutral, classification),
    };
    return Container(
      margin: const EdgeInsets.only(left: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
