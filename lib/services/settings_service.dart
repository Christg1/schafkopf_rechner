import 'package:shared_preferences/shared_preferences.dart';

// Keys for SharedPreferences
class SettingsKeys {
  static const String darkMode = 'isDarkMode';
  static const String showCents = 'showCentsInstead';
  static const String baseValue = 'defaultBaseValue';
}

// Pure data class
class Settings {
  final bool isDarkMode;
  final bool showCentsInstead;
  final int defaultBaseValue;

  const Settings({
    this.isDarkMode = false,
    this.showCentsInstead = false,
    this.defaultBaseValue = 10,
  });

  Settings copyWith({
    bool? isDarkMode,
    bool? showCentsInstead,
    int? defaultBaseValue,
  }) {
    return Settings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      showCentsInstead: showCentsInstead ?? this.showCentsInstead,
      defaultBaseValue: defaultBaseValue ?? this.defaultBaseValue,
    );
  }
}

/// Handles raw storage operations
class SettingsService {
  Future<Settings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool(SettingsKeys.darkMode) ?? false;
    final showCentsInstead = prefs.getBool(SettingsKeys.showCents) ?? false;
    final defaultBaseValue = prefs.getInt(SettingsKeys.baseValue) ?? 10;

    print('Loaded settings: isDarkMode=$isDarkMode, showCentsInstead=$showCentsInstead, defaultBaseValue=$defaultBaseValue');

    return Settings(
      isDarkMode: isDarkMode,
      showCentsInstead: showCentsInstead,
      defaultBaseValue: defaultBaseValue,
    );
  }

  Future<void> saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }
} 