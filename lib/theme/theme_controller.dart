import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeModeKey = 'theme_mode';

/// The app's light/dark/system preference — a single global ValueNotifier
/// rather than a full state-management package, since this is the only
/// piece of cross-screen mutable UI state in the app that isn't already
/// owned by a repository. GuimaVentApp listens to this to pick
/// MaterialApp's themeMode; SettingsScreen calls setThemeMode() to change
/// it. Persisted via SharedPreferences so the choice survives app restarts.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);

  /// Loads the previously-saved preference, if any. Call once at startup
  /// before the first frame (see main.dart) — defaults to ThemeMode.system
  /// when nothing has been saved yet.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = _fromName(prefs.getString(_themeModeKey)) ?? ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  static ThemeMode? _fromName(String? name) {
    for (final mode in ThemeMode.values) {
      if (mode.name == name) return mode;
    }
    return null;
  }
}

/// The real app-wide controller. Every real call site (GuimaVentApp,
/// SettingsScreen) defaults to this; tests construct their own
/// ThemeController instance instead so they don't share state with each
/// other or with a real SharedPreferences-backed instance.
final ThemeController themeController = ThemeController();
