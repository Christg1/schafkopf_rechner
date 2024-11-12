import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/settings_service.dart';

part 'settings_provider.g.dart';

@Riverpod(keepAlive: true)
class SettingsNotifier extends _$SettingsNotifier {
  late final SettingsService _service;

  @override
  Future<Settings> build() async {
    _service = SettingsService();
    try {
      final settings = await _service.loadSettings();
      print('Settings loaded successfully: $settings');
      return settings;
    } catch (e) {
      print('Error loading settings: $e');
      // Return default settings in case of error
      return const Settings();
    }
  }

  Future<void> toggleDarkMode() async {
    final settings = await future;
    final newSettings = settings.copyWith(isDarkMode: !settings.isDarkMode);
    await _service.saveSetting(SettingsKeys.darkMode, newSettings.isDarkMode);
    state = AsyncData(newSettings);
  }

  Future<void> toggleShowCents() async {
    final settings = await future;
    final newSettings = settings.copyWith(showCentsInstead: !settings.showCentsInstead);
    await _service.saveSetting(SettingsKeys.showCents, newSettings.showCentsInstead);
    state = AsyncData(newSettings);
  }

  Future<void> updateBaseValue(int value) async {
    final settings = await future;
    final newSettings = settings.copyWith(defaultBaseValue: value);
    await _service.saveSetting(SettingsKeys.baseValue, value);
    state = AsyncData(newSettings);
  }
} 