import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:case_thread/features/rooms/discussion_flags.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('toggleStar adds and removes a message id', () async {
    SharedPreferences.setMockInitialValues({});
    await DiscussionFlagsNotifier.init();

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier =
        container.read(discussionFlagsProvider('room-1').notifier);

    expect(container.read(discussionFlagsProvider('room-1')).isStarred('m-1'),
        isFalse);
    notifier.toggleStar('m-1');
    expect(container.read(discussionFlagsProvider('room-1')).isStarred('m-1'),
        isTrue);
    notifier.toggleStar('m-1');
    expect(container.read(discussionFlagsProvider('room-1')).isStarred('m-1'),
        isFalse);
  });

  test('togglePin adds and removes a message id', () async {
    SharedPreferences.setMockInitialValues({});
    await DiscussionFlagsNotifier.init();

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier =
        container.read(discussionFlagsProvider('room-1').notifier);

    notifier.togglePin('m-2');
    final flags = container.read(discussionFlagsProvider('room-1'));
    expect(flags.isPinned('m-2'), isTrue);
    expect(flags.isStarred('m-2'), isFalse); // independent sets

    notifier.togglePin('m-2');
    expect(container.read(discussionFlagsProvider('room-1')).isPinned('m-2'),
        isFalse);
  });

  test('flags persist across container restarts and are room-scoped', () async {
    SharedPreferences.setMockInitialValues({});
    await DiscussionFlagsNotifier.init();

    final container = ProviderContainer();
    container
        .read(discussionFlagsProvider('room-1').notifier)
      ..toggleStar('m-1')
      ..togglePin('m-1');
    container.read(discussionFlagsProvider('room-2').notifier).toggleStar('m-9');
    container.dispose();

    // New container over the same (mock) prefs store — starred/pinned
    // ids survive; the other room's flags stay separate.
    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    final flags1 = container2.read(discussionFlagsProvider('room-1'));
    final flags2 = container2.read(discussionFlagsProvider('room-2'));
    expect(flags1.isStarred('m-1'), isTrue);
    expect(flags1.isPinned('m-1'), isTrue);
    expect(flags2.isStarred('m-9'), isTrue);
    expect(flags2.isStarred('m-1'), isFalse);
  });
}
