import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted theme preference. Defaults to system (follows platform).
///
/// Phase 1 PRD: theme choice survives restarts via shared_preferences.
/// Only ThemeMode.values entries are persisted; any corrupt stored value
/// falls back to system.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  static final List<String> _valid = ThemeMode.values
      .map((v) => v.name)
      .toList();

  @override
  ThemeMode build() {
    final stored = _prefs?.getString(_key);
    if (stored != null && _valid.contains(stored)) {
      return ThemeMode.values.firstWhere((v) => v.name == stored);
    }
    return ThemeMode.system;
  }

  void toggle() {
    final next = switch (state) {
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.system,
      ThemeMode.system => ThemeMode.dark,
    };
    _set(next);
  }

  void set(ThemeMode mode) => _set(mode);

  Future<void> _set(ThemeMode mode) async {
    state = mode;
    await _prefs?.setString(_key, mode.name);
  }

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
}
