import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/core/errors/app_exceptions.dart';
import 'package:case_thread/features/rooms/domain/evidence_repository.dart';
import 'package:case_thread/features/rooms/domain/evidence_upload.dart';

/// Upload-validation contracts (PRD §6.4): the client pre-validates for
/// UX; the server re-enforces (0009). These tests pin the client side.
void main() {
  Uint8List bytes(int n) => Uint8List.fromList(List.filled(n, 7));

  group('EvidenceValidator.validate', () {
    test('accepts a normal PDF under the limit', () {
      expect(
        () => EvidenceValidator.validate(
          fileName: 'contract.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 2048,
        ),
        returnsNormally,
      );
    });

    test('rejects empty file names', () {
      expect(
        () => EvidenceValidator.validate(
          fileName: '  ',
          mimeType: 'application/pdf',
          sizeBytes: 10,
        ),
        throwsA(isA<EvidenceValidationException>()),
      );
    });

    test('rejects over-50MB files (PRD §6.4 limit)', () {
      expect(
        () => EvidenceValidator.validate(
          fileName: 'big.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 52428801,
        ),
        throwsA(
          isA<EvidenceValidationException>().having(
            (e) => e.message,
            'message',
            contains('50MB'),
          ),
        ),
      );
    });

    test('rejects empty (0-byte) files', () {
      expect(
        () => EvidenceValidator.validate(
          fileName: 'empty.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 0,
        ),
        throwsA(isA<EvidenceValidationException>()),
      );
    });

    test('rejects unsupported mime types (PRD §6.4 whitelist)', () {
      expect(
        () => EvidenceValidator.validate(
          fileName: 'movie.mp4',
          mimeType: 'video/mp4',
          sizeBytes: 100,
        ),
        throwsA(
          isA<EvidenceValidationException>().having(
            (e) => e.message,
            'message',
            contains('aren\'t supported'),
          ),
        ),
      );
    });

    test('accepts every whitelisted mime type', () {
      for (final mime in EvidenceValidator.allowedMimeTypes) {
        expect(
          () => EvidenceValidator.validate(
            fileName: 'f.bin',
            mimeType: mime,
            sizeBytes: 10,
          ),
          returnsNormally,
          reason: mime,
        );
      }
    });

    test('rejects file names over 200 chars', () {
      expect(
        () => EvidenceValidator.validate(
          fileName: 'x' * 250,
          mimeType: 'application/pdf',
          sizeBytes: 10,
        ),
        throwsA(isA<EvidenceValidationException>()),
      );
    });
  });

  group('EvidenceValidator.prepareFromBytes', () {
    test('computes the sha256 hex digest (chain-of-custody)', () {
      final prepared = EvidenceValidator.prepareFromBytes(
        fileName: 'notes.txt',
        mimeType: 'text/plain',
        bytes: Uint8List.fromList(List.filled(32, 0)),
      );

      // Known digest for 32 zero bytes.
      expect(
        prepared.sha256,
        '66687aadf862bd776c8fc18b8e9f8e20089714856ee233b3902a591d0d5f2925',
      );
      expect(prepared.sizeBytes, 32);
    });

    test('known-content digest (abc)', () {
      final prepared = EvidenceValidator.prepareFromBytes(
        fileName: 'a.txt',
        mimeType: 'text/plain',
        bytes: Uint8List.fromList('abc'.codeUnits),
      );
      expect(
        prepared.sha256,
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('extension→mime fallback maps common types', () {
      // prepare() uses _mimeFromExtension internally; exercise via the
      // public prepareFromBytes with an octet-stream and confirm the
      // validator rejects unknown extensions.
      expect(
        () => EvidenceValidator.prepareFromBytes(
          fileName: 'weird.xyz',
          mimeType: 'application/octet-stream',
          bytes: bytes(10),
        ),
        throwsA(isA<EvidenceValidationException>()),
      );
    });
  });

  group('VaultEntry', () {
    test('parses a full row with uploader name embed', () {
      final entry = VaultEntry.fromMap({
        'id': 'ev-1',
        'room_id': 'room-1',
        'filename': 'contract.pdf',
        'storage_path': 'rooms/room-1/abc-contract.pdf',
        'version': 2,
        'file_size_bytes': 2048,
        'mime_type': 'application/pdf',
        'file_hash': 'a'.padRight(64, 'a'),
        'uploaded_at': '2026-09-12T10:00:00Z',
        'profiles': {'display_name': 'Priya'},
      });

      expect(entry.displayName, 'contract.pdf (v2)');
      expect(entry.uploaderName, 'Priya');
      expect(entry.version, 2);
    });

    test('v1 files display the plain filename (no version suffix)', () {
      final entry = VaultEntry.fromMap({
        'id': 'ev-2',
        'room_id': 'room-1',
        'filename': 'a.pdf',
        'storage_path': 'rooms/room-1/x',
        'version': 1,
        'file_size_bytes': 1,
        'mime_type': 'application/pdf',
        'file_hash': 'b',
        'uploaded_at': '2026-09-12T10:00:00Z',
      });
      expect(entry.displayName, 'a.pdf');
    });

    test('missing optional fields fall back safely', () {
      final entry = VaultEntry.fromMap({
        'id': 'ev-3',
        'room_id': 'room-1',
        'filename': 'a.pdf',
        'storage_path': 'rooms/room-1/y',
        'uploaded_at': '2026-09-12T10:00:00Z',
      });
      expect(entry.version, 1);
      expect(entry.mimeType, 'application/octet-stream');
      expect(entry.uploaderName, isNull);
    });
  });
}
