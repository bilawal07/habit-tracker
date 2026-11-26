/// User-configurable app preferences persisted via SharedPreferences.
class AppSettings {
  const AppSettings({
    this.bundleNotifications = true,
    this.nightOwlGrace = false,
    this.darkMode = false,
  });

  final bool bundleNotifications;
  final bool nightOwlGrace;
  final bool darkMode;

  AppSettings copyWith({
    bool? bundleNotifications,
    bool? nightOwlGrace,
    bool? darkMode,
  }) {
    return AppSettings(
      bundleNotifications: bundleNotifications ?? this.bundleNotifications,
      nightOwlGrace: nightOwlGrace ?? this.nightOwlGrace,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}
