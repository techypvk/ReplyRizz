import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _keyMagicShake = 'magic_shake_enabled';
  static const String _keyShakeTooltip = 'shake_tooltip_seen';

  bool _isMagicShakeEnabled = false;
  bool _hasSeenShakeTooltip = false;

  bool get isMagicShakeEnabled => _isMagicShakeEnabled;
  bool get hasSeenShakeTooltip => _hasSeenShakeTooltip;

  Future<void> toggleMagicShake(bool value) async {
    _isMagicShakeEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMagicShake, value);
  }

  Future<void> markShakeTooltipSeen() async {
    if (_hasSeenShakeTooltip) return;
    _hasSeenShakeTooltip = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShakeTooltip, true);
  }

  static const String _keyThemeMode = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
  }

  // loadSettings to load theme too
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isMagicShakeEnabled = prefs.getBool(_keyMagicShake) ?? false;
    _hasSeenShakeTooltip = prefs.getBool(_keyShakeTooltip) ?? false;

    int? themeIndex = prefs.getInt(_keyThemeMode);
    if (themeIndex != null) {
      _themeMode = ThemeMode.values[themeIndex];
    }

    notifyListeners();
  }
}
