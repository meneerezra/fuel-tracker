import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'themeMode';

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  String? getServerUrl() {
    return _prefs.getString('serverUrl');
  }

  Future<void> saveServerUrl(String serverUrl) async {
    await _prefs.setString('serverUrl', serverUrl);
  }

  int? getCurrentCarId() {
    return _prefs.getInt('currentCarId');
  }

  Future<void> saveCurrentCarId(int carId) async {
    await _prefs.setInt('currentCarId', carId);
  }

  /// Last account and cars from the server, shown while offline.
  String? getCachedUser() => _prefs.getString('cachedUser');

  Future<void> saveCachedUser(String json) async {
    await _prefs.setString('cachedUser', json);
  }

  String? getCachedPrice(int carId) => _prefs.getString('cachedPrice.$carId');

  Future<void> saveCachedPrice(int carId, String json) async {
    await _prefs.setString('cachedPrice.$carId', json);
  }

  /// Removes the cached account and prices, for example after logging in with
  /// another token.
  Future<void> clearCache() async {
    for (final key in _prefs.getKeys()) {
      if (key == 'cachedUser' || key.startsWith('cachedPrice.')) {
        await _prefs.remove(key);
      }
    }
  }

  /// Km changes that are not on the server yet.
  String? getPendingKmChanges() => _prefs.getString('pendingKmChanges');

  Future<void> savePendingKmChanges(String json) async {
    await _prefs.setString('pendingKmChanges', json);
  }

  ThemeMode getDarkMode() {
    switch (_prefs.getString(_themeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveDarkMode(ThemeMode mode) async {
    await _prefs.setString('themeMode', mode.name);
  }
}
