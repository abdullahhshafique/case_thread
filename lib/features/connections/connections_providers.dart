import 'dart:convert';

// CaseThread Phase 6: Connections map (doc §13) — entities as nodes,
// relationships as edges, "why connected" via edge detail sheets.
import '../../../core/errors/error_mapper.dart';
import '../auth/auth_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One node in the relationship map (an entity).
class MapNode {
  const MapNode({
    required this.id,
    required this.type,
    required this.name,
    this.attributes = const {},
  });

  final String id;

  /// 'person' | 'location' | 'vehicle' | 'evidence' | 'org'
  final String type;
  final String name;
  final Map<String, dynamic> attributes;

  factory MapNode.fromMap(Map<String, dynamic> map) {
    final raw = map['attributes'];
    return MapNode(
      id: map['id'] as String,
      type: (map['type'] as String?) ?? 'person',
      name: (map['name'] as String?) ?? '',
      attributes: raw is Map ? Map<String, dynamic>.from(raw) : const {},
    );
  }
}

/// One directed edge (a relationship between two entities).
class MapEdge {
  const MapEdge({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.type,
  });

  final String id;
  final String fromId;
  final String toId;

  /// e.g. 'owns', 'spotted_at', 'witnessed'
  final String type;

  factory MapEdge.fromMap(Map<String, dynamic> map) {
    return MapEdge(
      id: map['id'] as String,
      fromId: (map['from'] ?? map['from_id']) as String,
      toId: (map['to'] ?? map['to_id']) as String,
      type: (map['type'] as String?) ?? 'related_to',
    );
  }
}

/// Full map payload from the 0016 get_entity_map RPC.
class EntityMapData {
  const EntityMapData({required this.nodes, required this.edges});

  final List<MapNode> nodes;
  final List<MapEdge> edges;

  factory EntityMapData.fromMap(Map<String, dynamic> map) {
    final nodes = (map['nodes'] as List? ?? [])
        .map((n) => MapNode.fromMap(Map<String, dynamic>.from(n as Map)))
        .toList();
    final edges = (map['edges'] as List? ?? [])
        .map((e) => MapEdge.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return EntityMapData(nodes: nodes, edges: edges);
  }

  MapNode? nodeById(String id) => nodes.where((n) => n.id == id).firstOrNull;
}

/// A published template carrying an `entity_seed` (0044) — the
/// Obsidian-templates import source.
class SeedTemplate {
  const SeedTemplate({
    required this.id,
    required this.displayName,
    required this.description,
    required this.seed,
  });

  final String id;
  final String displayName;
  final String description;
  final Map<String, dynamic> seed;

  factory SeedTemplate.fromMap(Map<String, dynamic> map) {
    final raw = map['entity_seed'];
    return SeedTemplate(
      id: map['id'] as String,
      displayName: (map['display_name'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      seed: raw is Map ? Map<String, dynamic>.from(raw) : const {},
    );
  }

  /// Entities as declared in the seed (stable keys + placeholders).
  List<Map<String, dynamic>> get entities =>
      [for (final e in (seed['entities'] as List? ?? []))
        Map<String, dynamic>.from(e as Map)];

  /// Relationships as declared (key references, not ids).
  List<Map<String, dynamic>> get relationships =>
      [for (final r in (seed['relationships'] as List? ?? []))
        Map<String, dynamic>.from(r as Map)];

  /// The {{placeholders}} the importer must fill (from entity names).
  List<String> get placeholders {
    final regex = RegExp(r'\{\{(\w+)\}\}');
    final out = <String>{};
    for (final e in entities) {
      out.addAll(regex.allMatches((e['name'] as String?) ?? '')
          .map((m) => m.group(1)!));
    }
    return out.toList()..sort();
  }
}

abstract class ConnectionsRepository {
  Future<EntityMapData> getMap(String roomId);

  /// Published templates that carry an entity seed (0044).
  Future<List<SeedTemplate>> listSeedTemplates();

  /// Creates a single entity (edit_case holders; entities-table RLS
  /// enforces). [note] rides the attributes JSONB.
  Future<MapNode> addEntity({
    required String roomId,
    required String entityType,
    required String name,
    String? note,
  });

  /// Imports a template's entity seed into the room (edit_case holders;
  /// 0044 RPC — placeholder substitution + key resolution + audit).
  Future<int> importEntitySeed({
    required String roomId,
    required String templateId,
    Map<String, String> values = const {},
  });

  /// Adds a relationship (edit_case holders; 0016 RLS enforces).
  Future<void> addRelationship({
    required String roomId,
    required String fromEntityId,
    required String toEntityId,
    required String relationshipType,
  });
}

class SupabaseConnectionsRepository implements ConnectionsRepository {
  SupabaseConnectionsRepository(this._client);

  final dynamic _client;

  @override
  Future<EntityMapData> getMap(String roomId) async {
    try {
      final result = await _client.rpc(
        'get_entity_map',
        params: {'target_room': roomId},
      );
      return EntityMapData.fromMap(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<MapNode> addEntity({
    required String roomId,
    required String entityType,
    required String name,
    String? note,
  }) async {
    try {
      final row = await _client
          .from('entities')
          .insert({
            'room_id': roomId,
            'entity_type': entityType,
            'name': name,
            'attributes': note == null || note.isEmpty
                ? '{}'
                : jsonEncode({'note': note}),
          })
          .select('id, type, name, attributes')
          .single();
      return MapNode.fromMap(Map<String, dynamic>.from(row));
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<List<SeedTemplate>> listSeedTemplates() async {
    try {
      final rows = await _client
          .from('case_type_templates')
          .select('id, display_name, description, entity_seed')
          .eq('is_published', true)
          .not('entity_seed', 'is', null)
          .order('display_name');
      return (rows as List)
          .map((r) => SeedTemplate.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<int> importEntitySeed({
    required String roomId,
    required String templateId,
    Map<String, String> values = const {},
  }) async {
    try {
      final result = await _client.rpc(
        'materialize_entity_seed',
        params: {
          'p_room': roomId,
          'p_template_id': templateId,
          'p_values': values,
        },
      );
      return (result as num?)?.toInt() ?? 0;
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<void> addRelationship({
    required String roomId,
    required String fromEntityId,
    required String toEntityId,
    required String relationshipType,
  }) async {
    try {
      await _client.from('entity_relationships').insert({
        'room_id': roomId,
        'from_entity_id': fromEntityId,
        'to_entity_id': toEntityId,
        'relationship_type': relationshipType,
      });
    } catch (error) {
      throw toAppException(error);
    }
  }
}

final connectionsRepositoryProvider = Provider<ConnectionsRepository>((ref) {
  return SupabaseConnectionsRepository(ref.watch(supabaseClientProvider));
});

/// Published templates with an entity seed (the import picker).
final seedTemplatesProvider = FutureProvider<List<SeedTemplate>>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(connectionsRepositoryProvider).listSeedTemplates();
});

final entityMapProvider = FutureProvider.family<EntityMapData, String>((
  ref,
  roomId,
) {
  ref.watch(sessionProvider);
  return ref.watch(connectionsRepositoryProvider).getMap(roomId);
});
