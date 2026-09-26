import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 5 (discussion enhancements): per-room starred + pinned message
/// ids. Client-side flags persisted via SharedPreferences — they mark
/// what THIS investigator wants to keep in view; they are not case data
/// and never touch the timeline or audit log.
class DiscussionFlags {
  const DiscussionFlags({
    this.starred = const {},
    this.pinned = const {},
  });

  final Set<String> starred;
  final Set<String> pinned;

  bool isStarred(String messageId) => starred.contains(messageId);
  bool isPinned(String messageId) => pinned.contains(messageId);

  DiscussionFlags copyWith({Set<String>? starred, Set<String>? pinned}) =>
      DiscussionFlags(
        starred: starred ?? this.starred,
        pinned: pinned ?? this.pinned,
      );
}

/// Riverpod 3.4.3: a family notifier's create function receives the
/// family argument — so it goes through the constructor (the `build`
/// override stays parameterless in this version).
final discussionFlagsProvider =
    NotifierProvider.family<DiscussionFlagsNotifier, DiscussionFlags, String>(
      DiscussionFlagsNotifier.new,
    );

class DiscussionFlagsNotifier extends Notifier<DiscussionFlags> {
  DiscussionFlagsNotifier(this.roomId);

  /// The family argument (room id) used for the persistence keys.
  final String roomId;

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String get _starKey => 'discussion_starred_$roomId';
  String get _pinKey => 'discussion_pinned_$roomId';

  @override
  DiscussionFlags build() {
    final prefs = _prefs;
    if (prefs == null) return const DiscussionFlags();
    return DiscussionFlags(
      starred: prefs.getStringList(_starKey)?.toSet() ?? const <String>{},
      pinned: prefs.getStringList(_pinKey)?.toSet() ?? const <String>{},
    );
  }

  void toggleStar(String messageId) {
    final next = <String>{...state.starred};
    if (!next.remove(messageId)) next.add(messageId);
    state = state.copyWith(starred: next);
    _prefs?.setStringList(_starKey, next.toList());
  }

  void togglePin(String messageId) {
    final next = <String>{...state.pinned};
    if (!next.remove(messageId)) next.add(messageId);
    state = state.copyWith(pinned: next);
    _prefs?.setStringList(_pinKey, next.toList());
  }
}
