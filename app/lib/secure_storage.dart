import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _authToken = 'access_token';

  final FlutterSecureStorage _storage;

  AuthStorage(this._storage);

  Future<void> saveToken(int authToken) async {
    await _storage.write(key: _authToken, value: authToken.toString());
  }

  Future<int?> getAuthToken() async {
    final token = await _storage.read(key: _authToken);
    return token != null ? int.tryParse(token) : null;
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _authToken);
  }
}
