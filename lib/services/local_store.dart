import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress.dart';
import '../models/settings.dart';

/// Saves settings and practice history on the device (shared preferences:
/// app storage on Android and iOS, local storage on the web). Nothing leaves it.
class LocalStore {
  LocalStore(this._prefs);

  static Future<LocalStore> open() async => LocalStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _settingsKey = 'settings.v1';
  static const _progressKey = 'progress.v1';
  static const _daysKey = 'days.v1';
  static const _importedPrefix = 'pack.v1.';

  /// Days of history kept for the progress screen.
  static const keepDays = 400;

  AppSettings loadSettings() {
    final map = _decodeMap(_prefs.getString(_settingsKey));
    return map == null ? const AppSettings() : AppSettings.fromJson(map);
  }

  Future<void> saveSettings(AppSettings settings) => _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));

  Map<String, ItemProgress> loadProgress() {
    final map = _decodeMap(_prefs.getString(_progressKey)) ?? const {};
    return {
      for (final entry in map.entries)
        if (entry.value is Map) entry.key: ItemProgress.fromJson((entry.value as Map).cast<String, Object?>()),
    };
  }

  Future<void> saveProgress(Map<String, ItemProgress> progress) =>
      _prefs.setString(_progressKey, jsonEncode({for (final e in progress.entries) e.key: e.value.toJson()}));

  List<DayLog> loadDays() {
    final raw = _prefs.getString(_daysKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (e is Map) DayLog.fromJson(e.cast<String, Object?>()),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> saveDays(List<DayLog> days) {
    final kept = days.length > keepDays ? days.sublist(days.length - keepDays) : days;
    return _prefs.setString(_daysKey, jsonEncode([for (final d in kept) d.toJson()]));
  }

  Future<void> clearProgress() async {
    await _prefs.remove(_progressKey);
    await _prefs.remove(_daysKey);
  }

  /// Packs imported on the web, where there is no file system: id -> JSON
  /// (with pictures embedded).
  Map<String, String> loadImportedPackBlobs() => {
    for (final key in _prefs.getKeys())
      if (key.startsWith(_importedPrefix)) key.substring(_importedPrefix.length): _prefs.getString(key) ?? '',
  };

  Future<void> saveImportedPackBlob(String id, String blob) => _prefs.setString('$_importedPrefix$id', blob);

  Future<void> removeImportedPackBlob(String id) => _prefs.remove('$_importedPrefix$id');

  static Map<String, Object?>? _decodeMap(String? raw) {
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map ? value.cast<String, Object?>() : null;
    } on FormatException {
      return null;
    }
  }
}
