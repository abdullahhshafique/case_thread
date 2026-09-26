import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'data/supabase_evidence_repository.dart' show evidenceRepositoryProvider;
import 'domain/evidence_repository.dart';
import 'domain/evidence_upload.dart';
import 'evidence_detail_sheet.dart';
import '../../core/api/models.dart' show Permission;
import 'room_permissions.dart';
import 'vault_providers.dart';

/// Evidence vault pane (Sprint 4): list + upload, permission-aware
/// error surfacing (PRD §6.7 — role-specific messages, never raw 403).
/// v3 §7 presentation: search field + type chips + console rows.
class VaultPane extends ConsumerStatefulWidget {
  const VaultPane({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<VaultPane> createState() => _VaultPaneState();
}

class _VaultPaneState extends ConsumerState<VaultPane> {
  final _searchController = TextEditingController();
  String _typeFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<VaultEntry> _filtered(List<VaultEntry> entries) {
    final query = _searchController.text.toLowerCase().trim();
    return entries.where((e) {
      final matchesType = switch (_typeFilter) {
        'all' => true,
        'pdf' => e.mimeType == 'application/pdf',
        'image' => e.mimeType.startsWith('image/'),
        'video' => e.mimeType.startsWith('video/'),
        'audio' => e.mimeType.startsWith('audio/'),
        _ => true,
      };
      final matchesQuery =
          query.isEmpty || e.displayName.toLowerCase().contains(query);
      return matchesType && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultProvider(widget.roomId));
    final progress = ref.watch(uploadProgressProvider(widget.roomId));
    final canUpload = ref
        .watch(myRoomPermissionsProvider(widget.roomId))
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
              onRetry: () => ref.invalidate(vaultProvider(widget.roomId)),
            ),
            data: (vault) => switch (vault) {
              VaultError(:final message) => _ErrorPane(
                message: message,
                onRetry: () => ref.invalidate(vaultProvider(widget.roomId)),
              ),
              VaultLoaded(:final entries) => Column(
                children: [
                  _VaultToolbar(
                    searchController: _searchController,
                    typeFilter: _typeFilter,
                    onType: (t) => setState(() => _typeFilter = t),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(vaultProvider(widget.roomId));
                        // Wait for the reload so the spinner behaves.
                        await ref.read(vaultProvider(widget.roomId).future);
                      },
                      child: _filtered(entries).isEmpty
                          ? ListView(
                              // scrollable for RefreshIndicator
                              children: const [
                                SizedBox(height: 120),
                                _EmptyVault(),
                              ],
                            )
                          : ListView.builder(
                              itemCount: _filtered(entries).length,
                              itemBuilder: (context, index) => _EvidenceTile(
                                entry: _filtered(entries)[index],
                              ),
                            ),
                    ),
                  ),
                ],
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
          .read(uploadProgressProvider(widget.roomId).notifier)
          .update(UploadProgress(fileName: prepared.fileName, progress: 0.1));
      await ref
          .read(evidenceRepositoryProvider)
          .upload(
            roomId: widget.roomId,
            file: prepared,
            onProgress: (p) => ref
                .read(uploadProgressProvider(widget.roomId).notifier)
                .update(
                  UploadProgress(fileName: prepared.fileName, progress: p),
                ),
          );
      ref.read(uploadProgressProvider(widget.roomId).notifier).update(null);
      ref.invalidate(vaultProvider(widget.roomId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded "${prepared.fileName}" to the vault.'),
          ),
        );
      }
    } on AppException catch (error) {
      ref.read(uploadProgressProvider(widget.roomId).notifier).update(null);
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

/// v3 §7 vault toolbar: console search field + type filter chips.
class _VaultToolbar extends StatelessWidget {
  const _VaultToolbar({
    required this.searchController,
    required this.typeFilter,
    required this.onType,
  });

  final TextEditingController searchController;
  final String typeFilter;
  final ValueChanged<String> onType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const Key('vault-search'),
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.consoleBorder),
              color: AppColors.consolePanel,
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.search, size: 15, color: AppColors.consoleMuted),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => onType(typeFilter), // re-run filter
                    style: const TextStyle(
                      color: AppColors.consoleText,
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search the vault',
                      hintStyle: TextStyle(
                        color: AppColors.consoleMuted,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            runSpacing: 4,
            children: [
              for (final (id, label) in const [
                ('all', 'All'),
                ('pdf', 'PDF'),
                ('image', 'Images'),
                ('video', 'Video'),
                ('audio', 'Audio'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    key: Key('vault-type-$id'),
                    label: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: typeFilter == id
                            ? AppColors.v3Info
                            : AppColors.consoleMuted,
                      ),
                    ),
                    selected: typeFilter == id,
                    onSelected: (_) => onType(id),
                    selectedColor: AppColors.v3IndigoTint,
                    side: BorderSide(
                      color: typeFilter == id
                          ? AppColors.graphEdge
                          : AppColors.consoleBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 6,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidenceTile extends ConsumerWidget {
  const _EvidenceTile({required this.entry});

  final VaultEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final (icon, tint) = switch (entry.mimeType) {
      final m when m.startsWith('image/') => (
        Icons.image_outlined,
        AppColors.statusOpen.withValues(alpha: 0.10),
      ),
      final m when m.startsWith('video/') => (
        Icons.videocam_outlined,
        AppColors.statusGap.withValues(alpha: 0.10),
      ),
      final m when m.startsWith('audio/') => (
        Icons.graphic_eq,
        AppColors.statePending.withValues(alpha: 0.10),
      ),
      _ => (Icons.description_outlined, AppColors.stateSuccess.withValues(alpha: 0.10)),
    };

    // Phase 4: tapping a tile opens the evidence detail sheet
    // (metadata + AI analysis + verify-alibi).
    return InkWell(
      key: Key('vault-entry-${entry.id}'),
      onTap: () => EvidenceDetailSheet.show(context, entry.roomId, entry),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: AppColors.consoleBorder),
        ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: tint,
            ),
            child: Icon(icon, size: 19, color: AppColors.consoleText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.displayName,
                        style: text.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.consoleBorder),
                      ),
                      child: Text(
                        'v${entry.version}',
                        style: text.labelSmall?.copyWith(
                          fontFamily: 'GeistMono',
                          color: AppColors.consoleMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatSize(entry.sizeBytes)} · '
                  '${entry.uploaderName ?? 'Member'} · '
                  '${_shortDate(entry.uploadedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.consoleMuted,
                  ),
                ),
              ],
            ),
          ),
          if (entry.classification != null)
            _VaultClassificationBadge(classification: entry.classification!),
          IconButton(
            tooltip: 'Download',
            icon: const Icon(Icons.download_outlined, size: 19),
            color: AppColors.consoleMuted,
            onPressed: () => _download(context, ref),
          ),
        ],
      ),
      ),
    );
  }

  static String _shortDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
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
