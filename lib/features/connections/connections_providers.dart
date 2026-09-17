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

  MapNode? nodeById(String id) =>
      nodes.where((n) => n.id == id).firstOrNull;
}

abstract class ConnectionsRepository {
  Future<EntityMapData> getMap(String roomId);

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

final entityMapProvider =
    FutureProvider.family<EntityMapData, String>((ref, roomId) {
  ref.watch(sessionProvider);
  return ref.watch(connectionsRepositoryProvider).getMap(roomId);
});
