import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/features/rooms/presence.dart';

void main() {
  group('lastSeenLabel', () {
    final now = DateTime(2026, 9, 24, 12, 0);

    test('just now under a minute', () {
      expect(lastSeenLabel(now.subtract(const Duration(seconds: 30)), now),
          'just now');
    });

    test('minutes', () {
      expect(lastSeenLabel(now.subtract(const Duration(minutes: 5)), now),
          '5m ago');
    });

    test('hours', () {
      expect(lastSeenLabel(now.subtract(const Duration(hours: 3)), now),
          '3h ago');
    });

    test('days', () {
      expect(lastSeenLabel(now.subtract(const Duration(days: 2)), now),
          '2d ago');
    });
  });

  group('roleDotColor', () {
    test('known roles map to distinct colors', () {
      final colors = [
        roleDotColor('lead_investigator'),
        roleDotColor('analyst'),
        roleDotColor('forensic'),
        roleDotColor('viewer'),
      ];
      expect(colors.toSet().length, colors.length);
    });

    test('unknown role falls back to a color (never throws)', () {
      expect(roleDotColor('mystery_role'), isA<Color>());
    });
  });
}
