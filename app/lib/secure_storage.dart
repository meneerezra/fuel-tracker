import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _authToken = 'access_token';

  final FlutterSecureStorage _storage;

  AuthStorage(this._storage);

  Future<void> saveToken(String authToken) async {
    await _storage.write(key: _authToken, value: authToken);
  }

  Future<String?> getAuthToken() {
    return _storage.read(key: _authToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _authToken);
  }
}
