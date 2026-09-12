import 'evidence_upload.dart';

/// Vault contract (Sprint 4): reads use PostgREST under 0005 RLS;
/// writes go through the 0009 register_evidence RPC — the client can
/// never insert evidence rows directly (policy removed in 0009).
abstract class EvidenceRepository {
  /// All evidence for a room, newest first (RLS: members only).
  Future<List<VaultEntry>> listForRoom(String roomId);

  /// Uploads bytes to the evidence bucket at `rooms/<roomId>/<name>`,
  /// then registers the row via the RPC (audit + version + hash).
  /// [onProgress] receives 0.0–1.0 during the storage upload.
  Future<EvidenceUploadResult> upload({
    required String roomId,
    required PreparedEvidence file,
    void Function(double progress)? onProgress,
  });

  /// Signed, time-limited download URL for an entry (Architecture.md §7
  /// export pattern — storage reads are member-gated).
  Future<Uri> downloadUrl(VaultEntry entry);
}

/// One evidence row as the vault list renders it.
class VaultEntry {
  const VaultEntry({
    required this.id,
    required this.roomId,
    required this.filename,
    required this.storagePath,
    required this.version,
    required this.sizeBytes,
    required this.mimeType,
    required this.sha256,
    required this.uploadedAt,
    this.uploaderName,
  });

  final String id;
  final String roomId;
  final String filename;
  final String storagePath;
  final int version;
  final int sizeBytes;
  final String mimeType;
  final String sha256;
  final DateTime uploadedAt;

  /// Resolved from profiles via FK embed when available.
  final String? uploaderName;

  factory VaultEntry.fromMap(Map<String, dynamic> map) {
    return VaultEntry(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      filename: map['filename'] as String,
      storagePath: map['storage_path'] as String,
      version: (map['version'] as num?)?.toInt() ?? 1,
      sizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
      mimeType: (map['mime_type'] as String?) ?? 'application/octet-stream',
      sha256: (map['file_hash'] as String?) ?? '',
      uploadedAt: DateTime.parse(map['uploaded_at'] as String),
      uploaderName: map['profiles'] is Map<String, dynamic>
          ? (map['profiles'] as Map<String, dynamic>)['display_name'] as String?
          : null,
    );
  }

  /// Display form: filename plus version tag when beyond v1
  /// (duplicate names auto-version — PRD §6.4).
  String get displayName => version > 1 ? '$filename (v$version)' : filename;
}
