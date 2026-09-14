import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/features/templates/templates.dart';

/// Phase 4 template-marketplace contracts (0021): draft parsing, role
/// grid round-trips, editor defaults, and the JSON shape publish
/// consumes.
void main() {
  group('CaseTypeTemplate', () {
    test('parses a draft with roles', () {
      final t = CaseTypeTemplate.fromMap({
        'id': 'tpl-1',
        'slug': 'journalism',
        'display_name': 'Journalism Room',
        'description': 'Editorial investigations.',
        'owner_role': 'editor',
        'roles': [
          {
            'slug': 'editor',
            'display_name': 'Editor',
            'is_lead_tier': true,
            'permissions': {
              'view_case': true,
              'edit_case': true,
              'approve_ai_findings': true,
            },
          },
          {
            'slug': 'contributor',
            'display_name': 'Contributor',
            'is_lead_tier': false,
            'permissions': {'view_case': true},
          },
        ],
        'is_published': false,
        'published_case_type': null,
      });

      expect(t.slug, 'journalism');
      expect(t.isPublished, isFalse);
      expect(t.roles.length, 2);
      expect(t.roles.first.isLeadTier, isTrue);
      expect(t.roles.first.permissions['approve_ai_findings'], isTrue);
      expect(t.roles.last.permissions['edit_case'], isNull); // absent key
    });

    test('parses a published template with case type reference', () {
      final t = CaseTypeTemplate.fromMap({
        'id': 'tpl-2',
        'slug': 'journalism',
        'display_name': 'Journalism Room',
        'description': '',
        'owner_role': 'editor',
        'roles': [],
        'is_published': true,
        'published_case_type': 'journalism',
      });

      expect(t.isPublished, isTrue);
      expect(t.publishedCaseType, 'journalism');
    });

    test('non-map permissions and non-list roles parse defensively', () {
      final t = CaseTypeTemplate.fromMap({
        'id': 'tpl-3',
        'slug': 'x',
        'display_name': 'X',
        'description': null,
        'owner_role': 'lead',
        'roles': null,
        'is_published': false,
      });

      expect(t.roles, isEmpty);
      expect(t.description, '');
    });

    test('round-trips through toMap (save path shape)', () {
      final map = {
        'id': 'tpl-1',
        'slug': 'journalism',
        'display_name': 'Journalism Room',
        'description': 'Editorial investigations.',
        'owner_role': 'editor',
        'roles': [
          {
            'slug': 'editor',
            'display_name': 'Editor',
            'is_lead_tier': true,
            'permissions': {'view_case': true, 'edit_case': true},
          },
        ],
        'is_published': false,
        'published_case_type': null,
      };
      final t = CaseTypeTemplate.fromMap(map);
      final out = t.toMap();

      expect(out['slug'], 'journalism');
      expect(out['owner_role'], 'editor');
      expect((out['roles'] as List).length, 1);
      // The save path sends the same keys the RPC validates.
      final role = (out['roles'] as List).first as Map<String, dynamic>;
      expect(role.containsKey('slug'), isTrue);
      expect(role.containsKey('display_name'), isTrue);
      expect(role.containsKey('is_lead_tier'), isTrue);
      expect(role.containsKey('permissions'), isTrue);
    });
  });

  group('TemplateRole', () {
    test('leadDefault carries the full 8-key grid', () {
      final lead = TemplateRole.leadDefault('lead', 'Lead');
      expect(lead.isLeadTier, isTrue);
      expect(lead.permissions.length, 8);
      expect(lead.permissions.values.every((v) => v), isTrue);
    });

    test('non-boolean permission values coerce to false (defensive)', () {
      final r = TemplateRole.fromMap({
        'slug': 'weird',
        'display_name': 'Weird',
        'is_lead_tier': 'yes', // string, not bool
        'permissions': {'view_case': 'true'}, // string value
      });

      // == true comparison: anything not literally true is false —
      // the safe default for a permission grid.
      expect(r.isLeadTier, isFalse);
      expect(r.permissions['view_case'], isFalse);
    });

    test('toMap emits the exact publish_template role shape', () {
      final map = TemplateRole.leadDefault('lead', 'Lead').toMap();
      expect(map.keys.toSet(), {
        'slug',
        'display_name',
        'is_lead_tier',
        'permissions',
      });
      expect(map['is_lead_tier'], isTrue);
      expect((map['permissions'] as Map<String, bool>)['view_case'], isTrue);
    });
  });

  group('Template slug rules (server-validated, mirrored client-side)', () {
    // The editor's regex must match the RPC's ^[a-z][a-z0-9_]{2,30}$.
    final regex = RegExp(r'^[a-z][a-z0-9_]{2,30}$');

    test('accepts valid slugs', () {
      for (final s in ['legal', 'journalism', 'case_review_2', 'a9b']) {
        expect(regex.hasMatch(s), isTrue, reason: s);
      }
    });

    test('rejects invalid slugs', () {
      for (final s in [
        'ab', // too short
        'Legal', // uppercase
        '2abc', // starts with digit
        'has space',
        'has-dash',
        'x' * 32, // too long
      ]) {
        expect(regex.hasMatch(s), isFalse, reason: s);
      }
    });
  });
}
