import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/supabase_evidence_repository.dart';
import 'domain/evidence_repository.dart';

/// Vault list state per room.
sealed class VaultState {
  const VaultState();
}

final class VaultLoaded extends VaultState {
  const VaultLoaded(this.entries);
  final List<VaultEntry> entries;
}

final class VaultError extends VaultState {
  const VaultError(this.message);
  final String message;
}

/// Upload-in-progress indicator per room.
class UploadProgress {
  const UploadProgress({required this.fileName, required this.progress});
  final String fileName;
  final double progress; // 0.0–1.0
}

/// Vault entries per room. Errors map to typed messages at the
/// repository boundary; here they're carried as VaultError for the UI.
/// Refresh = ref.invalidate(vaultProvider(roomId)) after uploads.
/// (Realtime updates arrive with Sprint 5's discussion work.)
final vaultProvider = FutureProvider.family<VaultState, String>((
  ref,
  roomId,
) async {
  try {
    final entries = await ref
        .watch(evidenceRepositoryProvider)
        .listForRoom(roomId);
    return VaultLoaded(entries);
  } catch (error) {
    return VaultError(error.toString());
  }
});

/// Live upload progress per room (null when idle). Riverpod 3 family:
/// plain Notifier subclass; the family arg arrives via constructor.
final uploadProgressProvider =
    NotifierProvider.family<UploadProgressNotifier, UploadProgress?, String>(
      (roomId) => UploadProgressNotifier(roomId),
    );

class UploadProgressNotifier extends Notifier<UploadProgress?> {
  UploadProgressNotifier(this.roomId);
  final String roomId;

  @override
  UploadProgress? build() => null;

  void update(UploadProgress? value) => state = value;
}
