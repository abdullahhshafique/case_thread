import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'activity_feed.dart';

/// Phase 7 presence: co-members' last-seen watermarks for one room.
final roomPresenceProvider =
    FutureProvider.family<Map<String, DateTime>, String>((ref, roomId) {
      return ref.watch(activityFeedRepositoryProvider).getRoomPresence(roomId);
    });

/// Role → dot color (Phase 7 role-colored presence dots). Color flags
/// the ROLE, never the person or any case state (Design.md §1 tone
/// rules); the role name always rides alongside as text.
Color roleDotColor(String roleId) => switch (roleId) {
  'lead_investigator' => AppColors.brandBlue,
  'analyst' => AppColors.statusGap,
  'forensic' => AppColors.v3Cyan,
  'legal_advisor' => AppColors.brandViolet,
  'viewer' => AppColors.statusNeutral,
  _ => AppColors.stateSuccess,
};

/// '5m ago' / '2h ago' / '3d ago' / 'just now' for a last-seen stamp.
String lastSeenLabel(DateTime lastSeenAt, DateTime now) {
  final diff = now.difference(lastSeenAt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
