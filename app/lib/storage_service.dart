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
