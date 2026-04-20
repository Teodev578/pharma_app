import 'package:flutter/material.dart';
import 'settings_service.dart';

class SettingsController with ChangeNotifier {
  SettingsController(this._settingsService);

  final SettingsService _settingsService;

  late ThemeMode _themeMode;
  late bool _notificationsEnabled;
  late double _searchRadius;

  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _notificationsEnabled;
  double get searchRadius => _searchRadius;

  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();
    _notificationsEnabled = await _settingsService.notificationsEnabled();
    _searchRadius = await _settingsService.searchRadius();
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;
    if (newThemeMode == _themeMode) return;

    _themeMode = newThemeMode;
    notifyListeners();
    await _settingsService.updateThemeMode(newThemeMode);
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    if (enabled == _notificationsEnabled) return;

    _notificationsEnabled = enabled;
    notifyListeners();
    await _settingsService.updateNotificationsEnabled(enabled);
  }

  Future<void> updateSearchRadius(double radius) async {
    if (radius == _searchRadius) return;

    _searchRadius = radius;
    notifyListeners();
    await _settingsService.updateSearchRadius(radius);
  }
}
