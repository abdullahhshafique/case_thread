import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/core/api/models.dart';

void main() {
  group('Alibi', () {
    test('parses a verified alibi', () {
      final a = Alibi.fromMap({
        'id': 'alibi-1',
        'room_id': 'room-1',
        'entity_id': 'entity-1',
        'claimed_window_start': '2026-09-01T08:00:00Z',
        'claimed_window_end': '2026-09-01T10:00:00Z',
        'claim_text': 'At the library',
        'source': 'self',
        'status': 'verified',
        'status_reason': 'Confirmed by librarian',
        'created_by': 'user-1',
        'verified_by': 'user-2',
        'created_at': '2026-09-13T10:00:00Z',
        'verified_at': '2026-09-13T11:00:00Z',
      });

      expect(a.id, 'alibi-1');
      expect(a.roomId, 'room-1');
      expect(a.entityId, 'entity-1');
      expect(a.claimText, 'At the library');
      expect(a.status, AlibiStatus.verified);
      expect(a.statusReason, 'Confirmed by librarian');
      expect(a.verifiedAt, isNotNull);
    });

    test('nullable fields default null', () {
      final a = Alibi.fromMap({
        'id': 'alibi-2',
        'room_id': 'room-1',
        'entity_id': 'entity-1',
        'claimed_window_start': '2026-09-01T08:00:00Z',
        'claimed_window_end': '2026-09-01T10:00:00Z',
        'claim_text': 'At the library',
        'status': 'open',
        'status_reason': 'Pending review',
        'created_at': '2026-09-13T10:00:00Z',
      });

      expect(a.source, isNull);
      expect(a.createdBy, isNull);
      expect(a.verifiedBy, isNull);
      expect(a.verifiedAt, isNull);
    });
  });

  group('AlibiStatus enum', () {
    test('round-trips via .name', () {
      final status = AlibiStatus.verified;
      expect(
        AlibiStatus.values.firstWhere((e) => e.name == status.name),
        status,
      );
    });
  });
}
