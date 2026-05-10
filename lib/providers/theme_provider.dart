import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemePreference { system, light, dark }

class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'themePreference';

  ThemePreference _themePreference = ThemePreference.light;

  bool get isDarkMode => _themePreference == ThemePreference.dark;
  bool get useSystemDefault => _themePreference == ThemePreference.system;

  ThemeMode get themeMode {
    switch (_themePreference) {
      case ThemePreference.system:
        return ThemeMode.system;
      case ThemePreference.light:
        return ThemeMode.light;
      case ThemePreference.dark:
        return ThemeMode.dark;
    }
  }

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeKey);
    _themePreference = value == null ? ThemePreference.light : _fromString(value);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    if (_themePreference == ThemePreference.system) {
      _themePreference = ThemePreference.dark;
    } else {
      _themePreference =
          _themePreference == ThemePreference.dark ? ThemePreference.light : ThemePreference.dark;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> setThemeMode(bool isDark) async {
    _themePreference = isDark ? ThemePreference.dark : ThemePreference.light;
    notifyListeners();
    await _persist();
  }

  Future<void> setUseSystemDefault(bool useSystem) async {
    _themePreference = useSystem ? ThemePreference.system : ThemePreference.light;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _themePreference.name);
  }

  ThemePreference _fromString(String? value) {
    switch (value) {
      case 'dark':
        return ThemePreference.dark;
      case 'light':
        return ThemePreference.light;
      case 'system':
        return ThemePreference.system;
      default:
        return ThemePreference.light;
    }
  }
}
