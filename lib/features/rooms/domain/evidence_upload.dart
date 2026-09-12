import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/errors/app_exceptions.dart';

/// Result of a successful register_evidence call (mirrors the RPC).
class EvidenceUploadResult {
  const EvidenceUploadResult({required this.evidenceId, required this.version});
  final String evidenceId;
  final int version;
}

/// A picked file prepared for upload (validated + hashed client-side;
/// the server re-validates everything — client checks are UX only).
class PreparedEvidence {
  const PreparedEvidence({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.sizeBytes,
    required this.sha256,
  });

  /// SHA-256 hex digest — chain-of-custody per PRD §6.4.
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final int sizeBytes;
  final String sha256;
}

/// Client-side pre-validation (PRD §6.4). Mirrors the server's rules
/// so users get instant feedback; the DB enforces regardless (0009).
class EvidenceValidator {
  static const int maxSizeBytes = 52428800; // 50MB

  static const Set<String> allowedMimeTypes = {
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/msword',
    'image/png',
    'image/jpeg',
    'image/webp',
    'text/plain',
    'audio/mpeg',
    'audio/mp4',
    'audio/wav',
    'audio/x-wav',
    'audio/webm',
    'audio/ogg',
  };

  static void validate({
    required String fileName,
    required String mimeType,
    required int sizeBytes,
  }) {
    if (fileName.trim().isEmpty) {
      throw const EvidenceValidationException(
        message: 'Pick a file to upload.',
      );
    }
    if (fileName.length > 200) {
      throw const EvidenceValidationException(
        message: 'The file name is too long (over 200 characters).',
      );
    }
    if (sizeBytes > maxSizeBytes) {
      throw const EvidenceValidationException(
        message: 'That file is over the 50MB limit.',
      );
    }
    if (sizeBytes <= 0) {
      throw const EvidenceValidationException(message: 'That file is empty.');
    }
    if (!allowedMimeTypes.contains(mimeType)) {
      throw EvidenceValidationException(
        message:
            'Files of type "$mimeType" aren\'t supported. '
            'Supported: PDF, DOC/DOCX, images, text, common audio.',
      );
    }
  }

  /// Reads + hashes the file, validating first. Returns the prepared
  /// payload for upload.
  static Future<PreparedEvidence> prepare(File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    // Cross-platform basic extension→mime fallback; file_picker's
    // reported type wins when available (caller passes it in).
    final bytes = await file.readAsBytes();
    return prepareFromBytes(
      fileName: fileName,
      mimeType: _mimeFromExtension(fileName),
      bytes: bytes,
    );
  }

  static PreparedEvidence prepareFromBytes({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) {
    validate(fileName: fileName, mimeType: mimeType, sizeBytes: bytes.length);
    return PreparedEvidence(
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
      sizeBytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
    );
  }

  static String _mimeFromExtension(String fileName) {
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
      'm4a' || 'mp4' => 'audio/mp4',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'webm' => 'audio/webm',
      _ => 'application/octet-stream',
    };
  }
}
