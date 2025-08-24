import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing app theme state
/// Supports light, dark, and system theme modes
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeFromPreferences();
  }

  /// Load saved theme preference from SharedPreferences
  Future<void> _loadThemeFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey) ?? 0;
      _themeMode = ThemeMode.values[themeIndex];
      notifyListeners();
    } catch (e) {
      // If loading fails, use system theme as default
      _themeMode = ThemeMode.system;
    }
  }

  /// Save theme preference to SharedPreferences
  Future<void> _saveThemeToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, _themeMode.index);
    } catch (e) {
      // If saving fails, continue without saving
    }
  }

  /// Set theme mode and save preference
  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (_themeMode != themeMode) {
      _themeMode = themeMode;
      await _saveThemeToPreferences();
      notifyListeners();
    }
  }

  /// Toggle between light and dark themes
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      // If system theme, switch to light theme
      await setThemeMode(ThemeMode.light);
    }
  }

  /// Check if current theme is dark
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      // Use system brightness as fallback
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  /// Get theme mode name for display
  String get themeModeName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  /// Get theme mode description
  String get themeModeDescription {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Always use light theme';
      case ThemeMode.dark:
        return 'Always use dark theme';
      case ThemeMode.system:
        return 'Follow system theme';
    }
  }
}
