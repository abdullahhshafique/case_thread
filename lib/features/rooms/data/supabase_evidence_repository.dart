import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_mapper.dart';
import '../../auth/auth_providers.dart';
import '../domain/evidence_repository.dart';
import '../domain/evidence_upload.dart';

/// Supabase-backed [EvidenceRepository]. Uploads are two-phase:
///   1. storage upload to `rooms/<roomId>/<evidenceId>/<name>` (RLS-gated)
///   2. register_evidence RPC (row + audit + versioning + hash check)
/// The object path embeds a fresh uuid so the same filename can be
/// uploaded repeatedly without object-name collisions — the DB owns
/// display-versioning.
class SupabaseEvidenceRepository implements EvidenceRepository {
  SupabaseEvidenceRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<VaultEntry>> listForRoom(String roomId) async {
    final rows = await _client
        .from('evidence_items')
        .select(
          'id, room_id, filename, storage_path, version, file_size_bytes, '
          'mime_type, file_hash, uploaded_at, classification, '
          'profiles!evidence_items_uploader_id_fkey(display_name)',
        )
        .eq('room_id', roomId)
        .order('uploaded_at', ascending: false);

    return (rows as List)
        .map((row) => VaultEntry.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<EvidenceUploadResult> upload({
    required String roomId,
    required PreparedEvidence file,
    void Function(double progress)? onProgress,
  }) async {
    // 1. Storage: room-scoped object path with a fresh uuid component.
    final objectPath =
        'rooms/$roomId/${_client.auth.currentUser?.id ?? ''}-${DateTime.now().millisecondsSinceEpoch}-${file.fileName}';

    try {
      await _client.storage
          .from('evidence')
          .uploadBinary(
            objectPath,
            file.bytes,
            fileOptions: supabase.FileOptions(
              contentType: file.mimeType,
              upsert: false,
            ),
          );
      onProgress?.call(0.5);
    } catch (error) {
      throw _mapStorageError(error);
    }

    // 2. Register the row (audit + versioning + server-side checks).
    try {
      final response = await _client.rpc(
        'register_evidence',
        params: {
          'target_room': roomId,
          'original_name': file.fileName,
          'object_path': objectPath,
          'file_mime': file.mimeType,
          'file_size': file.sizeBytes,
          'file_sha256': file.sha256,
        },
      );
      onProgress?.call(1.0);
      final row = response is List && response.isNotEmpty
          ? Map<String, dynamic>.from(response.first as Map)
          : Map<String, dynamic>.from(response as Map);
      return EvidenceUploadResult(
        evidenceId: row['evidence_id'] as String,
        version: (row['version_no'] as num).toInt(),
      );
    } catch (error) {
      // Row registration failed — remove the orphaned object so the
      // vault never shows a file without a row (PRD §6.4: partial
      // uploads must not be visible).
      try {
        await _client.storage.from('evidence').remove([objectPath]);
      } on Exception {
        // Cleanup is best-effort; the RPC failure is the signal.
      }
      throw _mapRpcError(error);
    }
  }

  @override
  Future<Uri> downloadUrl(VaultEntry entry) async {
    final url = await _client.storage
        .from('evidence')
        .createSignedUrl(entry.storagePath, 600);
    return Uri.parse(url);
  }

  AppException _mapStorageError(Object error) {
    final message = error.toString();
    if (message.contains('upload_evidence') ||
        message.contains('row-level security')) {
      return const UploadNotAllowedException();
    }
    return toAppException(error);
  }

  AppException _mapRpcError(Object error) {
    final message = error.toString();
    if (message.contains('cannot upload evidence')) {
      return const UploadNotAllowedException();
    }
    if (message.contains('50MB')) {
      return EvidenceRejectedServerException.fromMessage(
        'That file is over the 50MB limit.',
      );
    }
    if (message.contains('path does not match')) {
      return EvidenceRejectedServerException.fromMessage(
        'The upload path didn\'t match the room. Try again.',
      );
    }
    if (message.contains('Invalid file hash')) {
      return EvidenceRejectedServerException.fromMessage(
        'The file changed during upload. Try again.',
      );
    }
    return toAppException(error);
  }
}

final evidenceRepositoryProvider = Provider<EvidenceRepository>((ref) {
  return SupabaseEvidenceRepository(ref.watch(supabaseClientProvider));
});
