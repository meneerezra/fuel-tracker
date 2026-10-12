import 'dart:convert';

import 'package:http/http.dart' as http;

class Car {
  const Car({this.id, required this.name, this.ownerId});

  final int? id;
  final String name;
  final int? ownerId;

  factory Car.fromJson(Map<String, dynamic> json) => Car(
    id: json['id'] as int?,
    name: json['name'] as String,
    ownerId: json['owner_id'] as int?,
  );
}

class User {
  const User({
    required this.id,
    required this.authToken,
    required this.isSuperuser,
    required this.cars,
    required this.ownedCars,
  });

  final int id;
  final int authToken;
  final bool isSuperuser;
  final List<Car> cars;
  final List<Car> ownedCars;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    authToken: json['auth_token'] as int,
    isSuperuser: json['is_superuser'] as bool,
    cars: (json['cars'] as List<dynamic>)
        .map((e) => Car.fromJson(e as Map<String, dynamic>))
        .toList(),
    ownedCars: (json['owned_cars'] as List<dynamic>)
        .map((e) => Car.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class Api {
  Api({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBaseUrl;

  static const _defaultBaseUrl =
      'http://10.0.2.2:8000'; // Android emulator -> host localhost

  final String baseUrl;
  int? _authToken;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  Future<User> login(int authToken) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );
    if (response.statusCode != 200) {
      throw ApiException('Login failed (${response.statusCode})');
    }
    _authToken = authToken;
    return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<User> me() => _getUser('$baseUrl/users/me');

  Future<User> _getUser(String path) async {
    final response = await http.get(Uri.parse(path), headers: _headers);
    _ensureOk(response);
    return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Car> createCar(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cars/'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    _ensureOk(response);
    return Car.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<Car>> ownedCars() async {
    final user = await me();
    return user.ownedCars;
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Request failed (${response.statusCode})');
    }
  }
}
