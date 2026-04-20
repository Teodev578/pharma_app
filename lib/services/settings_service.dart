import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _themeModeKey = 'settings_theme_mode';
  static const String _notificationsKey = 'settings_notifications_enabled';
  static const String _searchRadiusKey = 'settings_search_radius';

  Future<ThemeMode> themeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_themeModeKey);
    if (index == null) return ThemeMode.system;
    return ThemeMode.values[index];
  }

  Future<void> updateThemeMode(ThemeMode theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, theme.index);
  }

  Future<bool> notificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsKey) ?? true;
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, enabled);
  }

  Future<double> searchRadius() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_searchRadiusKey) ?? 10.0;
  }

  Future<void> updateSearchRadius(double radius) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_searchRadiusKey, radius);
  }
}
