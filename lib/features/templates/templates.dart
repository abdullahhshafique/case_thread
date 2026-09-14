import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/errors/error_mapper.dart';
import '../auth/auth_providers.dart';

/// One role inside a template draft: display name + the 8-key
/// permission grid the editor builds (values validated server-side
/// by publish_template — 0021).
class TemplateRole {
  const TemplateRole({
    required this.slug,
    required this.displayName,
    required this.isLeadTier,
    required this.permissions,
  });

  final String slug;
  final String displayName;
  final bool isLeadTier;

  /// Permission key (e.g. 'edit_case') → allowed.
  final Map<String, bool> permissions;

  Map<String, dynamic> toMap() => {
    'slug': slug,
    'display_name': displayName,
    'is_lead_tier': isLeadTier,
    'permissions': permissions,
  };

  factory TemplateRole.fromMap(Map<String, dynamic> map) {
    final raw = map['permissions'];
    return TemplateRole(
      slug: map['slug'] as String,
      displayName: map['display_name'] as String,
      isLeadTier: map['is_lead_tier'] == true,
      permissions: raw is Map
          ? Map<String, bool>.from(
              raw.map((k, v) => MapEntry(k as String, v == true)),
            )
          : const {},
    );
  }

  /// Editor default: a Lead-tier role with the full grid — the shape
  /// new drafts start from (mirrors 0004's lead rows).
  static TemplateRole leadDefault(String slug, String displayName) {
    return TemplateRole(
      slug: slug,
      displayName: displayName,
      isLeadTier: true,
      permissions: const {
        'view_case': true,
        'edit_case': true,
        'upload_evidence': true,
        'comment': true,
        'approve_ai_findings': true,
        'manage_members': true,
        'export_reports': true,
        'view_privileged': true,
      },
    );
  }
}

/// A template draft (0021): author-private until published, then it
/// materializes into a real case type any user can create rooms with.
class CaseTypeTemplate {
  const CaseTypeTemplate({
    required this.id,
    required this.slug,
    required this.displayName,
    required this.description,
    required this.ownerRoleSlug,
    required this.roles,
    required this.isPublished,
    this.publishedCaseType,
  });

  final String id;

  /// Becomes the case_types.id on publish (server-validated).
  final String slug;
  final String displayName;
  final String description;

  /// Slug of the role that owns new rooms created from this template.
  final String ownerRoleSlug;
  final List<TemplateRole> roles;
  final bool isPublished;
  final String? publishedCaseType;

  bool get isMine => true; // repository only returns author's drafts

  Map<String, dynamic> toMap() => {
    'id': id,
    'slug': slug,
    'display_name': displayName,
    'description': description,
    'owner_role': ownerRoleSlug,
    'roles': [for (final r in roles) r.toMap()],
    'is_published': isPublished,
    'published_case_type': publishedCaseType,
  };

  factory CaseTypeTemplate.fromMap(Map<String, dynamic> map) {
    final rawRoles = map['roles'];
    return CaseTypeTemplate(
      id: map['id'] as String,
      slug: map['slug'] as String,
      displayName: map['display_name'] as String,
      description: (map['description'] as String?) ?? '',
      ownerRoleSlug: map['owner_role'] as String,
      roles: rawRoles is List
          ? rawRoles
                .map((r) => TemplateRole.fromMap(Map<String, dynamic>.from(r)))
                .toList()
          : const [],
      isPublished: map['is_published'] == true,
      publishedCaseType: map['published_case_type'] as String?,
    );
  }
}

/// Marketplace contract (0021): draft CRUD + publish (RPC), plus the
/// published listing every user sees.
abstract class TemplateRepository {
  /// The caller's own drafts (any state).
  Future<List<CaseTypeTemplate>> listMyTemplates();

  /// Published templates (marketplace listing) — may include the
  /// caller's own; UI groups by mine/others.
  Future<List<CaseTypeTemplate>> listPublished();

  Future<void> saveTemplate({
    required String slug,
    required String displayName,
    required String description,
    required String ownerRoleSlug,
    required List<TemplateRole> roles,
  });

  /// Publishes a draft → returns the new case type id.
  Future<String> publishTemplate(String templateId);

  Future<void> deleteTemplate(String templateId);
}

class SupabaseTemplateRepository implements TemplateRepository {
  SupabaseTemplateRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _select =
      'id, slug, display_name, description, owner_role, roles, '
      'is_published, published_case_type';

  @override
  Future<List<CaseTypeTemplate>> listMyTemplates() async {
    final rows = await _client
        .from('case_type_templates')
        .select(_select)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((r) => CaseTypeTemplate.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  @override
  Future<List<CaseTypeTemplate>> listPublished() async {
    final rows = await _client
        .from('case_type_templates')
        .select(_select)
        .eq('is_published', true)
        .order('display_name');
    return (rows as List)
        .map((r) => CaseTypeTemplate.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  @override
  Future<void> saveTemplate({
    required String slug,
    required String displayName,
    required String description,
    required String ownerRoleSlug,
    required List<TemplateRole> roles,
  }) async {
    try {
      await _client.from('case_type_templates').upsert({
        'slug': slug,
        'display_name': displayName,
        'description': description,
        'owner_role': ownerRoleSlug,
        'roles': [for (final r in roles) r.toMap()],
      }, onConflict: 'author,slug');
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<String> publishTemplate(String templateId) async {
    try {
      final result = await _client.rpc(
        'publish_template',
        params: {'template': templateId},
      );
      return result as String;
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    try {
      await _client.from('case_type_templates').delete().eq('id', templateId);
    } catch (error) {
      throw toAppException(error);
    }
  }
}

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return SupabaseTemplateRepository(ref.watch(supabaseClientProvider));
});

/// The caller's drafts.
final myTemplatesProvider = FutureProvider<List<CaseTypeTemplate>>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(templateRepositoryProvider).listMyTemplates();
});

/// The published marketplace listing.
final publishedTemplatesProvider = FutureProvider<List<CaseTypeTemplate>>((
  ref,
) {
  ref.watch(sessionProvider);
  return ref.watch(templateRepositoryProvider).listPublished();
});
