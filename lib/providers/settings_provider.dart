import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/app_settings.dart';
import 'database_provider.dart';

/// Manages [AppSettings] backed by [SharedPreferences].
class SettingsNotifier extends Notifier<AppSettings> {
  static const String _bundleKey = 'bundle_notifications';
  static const String _nightOwlKey = 'night_owl_grace';
  static const String _darkModeKey = 'dark_mode';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      bundleNotifications: prefs.getBool(_bundleKey) ?? true,
      nightOwlGrace: prefs.getBool(_nightOwlKey) ?? false,
      darkMode: prefs.getBool(_darkModeKey) ?? false,
    );
  }

  Future<void> setBundleNotifications(bool value) async {
    await _prefs.setBool(_bundleKey, value);
    state = state.copyWith(bundleNotifications: value);
  }

  Future<void> setNightOwlGrace(bool value) async {
    await _prefs.setBool(_nightOwlKey, value);
    state = state.copyWith(nightOwlGrace: value);
  }

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool(_darkModeKey, value);
    state = state.copyWith(darkMode: value);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
