import 'dart:convert';

import 'package:http/http.dart' as http;

enum FuelType {
  diesel('diesel'),
  e95('e95');

  const FuelType(this.value);

  final String value;

  static FuelType fromJson(String value) {
    return FuelType.values.firstWhere(
      (fuelType) => fuelType.value == value,
      orElse: () => throw FormatException('Unknown fuel type: $value'),
    );
  }
}

class Car {
  const Car({
    this.id,
    required this.name,
    this.ownerId,
    this.kmDriven = 0,
    this.kmTreshold = 0,
    this.totalKmDriven = 0,
    this.consumption = 0,
    required this.fuelType,
    this.countryCode = 'NL',
  });

  final int? id;
  final String name;
  final int? ownerId;
  final double kmDriven;
  final double kmTreshold;
  final double totalKmDriven;
  final double consumption;
  final FuelType fuelType;
  final String countryCode;

  Car copyWith({
    String? name,
    double? kmDriven,
    double? kmTreshold,
    double? totalKmDriven,
    double? consumption,
    FuelType? fuelType,
    String? countryCode,
  }) => Car(
    id: id,
    name: name ?? this.name,
    ownerId: ownerId,
    kmDriven: kmDriven ?? this.kmDriven,
    kmTreshold: kmTreshold ?? this.kmTreshold,
    totalKmDriven: totalKmDriven ?? this.totalKmDriven,
    consumption: consumption ?? this.consumption,
    fuelType: fuelType ?? this.fuelType,
    countryCode: countryCode ?? this.countryCode,
  );

  factory Car.fromJson(Map<String, dynamic> json) => Car(
    id: (json['id'] as num?)?.toInt(),
    name: json['name'] as String,
    ownerId: (json['owner_id'] as num?)?.toInt(),
    kmDriven: (json['km_driven'] as num?)?.toDouble() ?? 0,
    kmTreshold: (json['km_treshold'] as num?)?.toDouble() ?? 0,
    totalKmDriven: (json['total_km_driven'] as num?)?.toDouble() ?? 0,
    consumption: (json['consumption'] as num?)?.toDouble() ?? 0,
    fuelType: FuelType.fromJson(json['fuel_type'] as String),
    countryCode: json['country_code'] as String? ?? 'NL',
  );
}

class CarPrice {
  const CarPrice({
    this.fuelPrice,
    required this.pricePerKm,
    required this.pricePerThreshold,
  });

  final double? fuelPrice;
  final double pricePerKm;
  final double pricePerThreshold;

  factory CarPrice.fromJson(Map<String, dynamic> json) => CarPrice(
    fuelPrice: (json['fuel_price'] as num?)?.toDouble(),
    pricePerKm: (json['price_per_km'] as num).toDouble(),
    pricePerThreshold: (json['price_per_threshold'] as num).toDouble(),
  );
}

class User {
  const User({
    required this.id,
    this.name,
    required this.isSuperuser,
    required this.sharedCars,
    required this.ownedCars,
    this.authToken,
  });

  final int id;
  final String? name;
  final bool isSuperuser;
  final List<Car> sharedCars;
  final List<Car> ownedCars;

  /// Only sent when a user is created.
  final int? authToken;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String?,
    isSuperuser: json['is_superuser'] as bool,
    sharedCars: _carsFromJson(json['shared_cars']),
    ownedCars: _carsFromJson(json['owned_cars']),
    authToken: (json['auth_token'] as num?)?.toInt(),
  );

  static List<Car> _carsFromJson(Object? json) {
    // A created user is returned without cars.
    if (json == null) return [];
    return (json as List<dynamic>)
        .map((car) => Car.fromJson(car as Map<String, dynamic>))
        .toList();
  }
}

class SharedUser {
  const SharedUser({required this.id, this.name});

  final int id;
  final String? name;

  factory SharedUser.fromJson(Map<String, dynamic> json) => SharedUser(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String?,
  );

  static List<SharedUser> listFromJson(String body) {
    return (jsonDecode(body) as List<dynamic>)
        .map((user) => SharedUser.fromJson(user as Map<String, dynamic>))
        .toList();
  }
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class Api {
  Api({String? baseUrl, this.authToken})
    : baseUrl = _normalizeBaseUrl(baseUrl ?? _defaultBaseUrl);

  static const _defaultBaseUrl =
      'http://10.0.2.2:8000'; // Android emulator -> host localhost

  final String baseUrl;
  int? authToken;

  static String _normalizeBaseUrl(String url) {
    var trimmed = url.trim();
    if (trimmed.isEmpty) return _defaultBaseUrl;
    if (!trimmed.contains('://')) {
      trimmed = 'https://$trimmed';
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (authToken != null) 'Authorization': 'Bearer $authToken',
  };

  Future<User> login(int authToken) async {
    final response = await http.get(
      _uri('/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );
    _ensureOk(response, action: 'Login failed');
    this.authToken = authToken;
    return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<User> me() => _getUser('/users/me');

  /// All users with their cars. Superuser only.
  Future<List<User>> allUsers() async {
    final response = await http.get(_uri('/users/'), headers: _headers);
    _ensureOk(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((user) => User.fromJson(user as Map<String, dynamic>))
        .toList();
  }

  Future<User> _getUser(String path) async {
    final response = await http.get(_uri(path), headers: _headers);
    _ensureOk(response);
    return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Car> getCar(int carId) async {
    final response = await http.get(_uri('/cars/$carId'), headers: _headers);
    _ensureOk(response);
    return Car.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Car> createCar({
    required String name,
    required double kmThreshold,
    required FuelType fuelType,
    required double consumption,
    String countryCode = 'NL',
  }) async {
    final response = await http.post(
      _uri('/cars/'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'km_threshold': kmThreshold,
        'fuel_type': fuelType.value,
        'consumption': consumption,
        'country_code': countryCode,
      }),
    );
    _ensureOk(response);
    return Car.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Car> editCar({
    required int id,
    required String name,
    required double kmThreshold,
    required double kmDriven,
    required double totalKmDriven,
    required double consumption,
    required FuelType fuelType,
    String countryCode = 'NL',
  }) async {
    final response = await http.put(
      _uri('/cars/'),
      headers: _headers,
      body: jsonEncode({
        'id': id,
        'name': name,
        'km_threshold': kmThreshold,
        'km_driven': kmDriven,
        'total_km_driven': totalKmDriven,
        'consumption': consumption,
        'fuel_type': fuelType.value,
        'country_code': countryCode,
      }),
    );
    _ensureOk(response);
    return Car.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteCar(int id) async {
    final response = await http.delete(
      _uri('/cars/'),
      headers: _headers,
      body: jsonEncode({'id': id}),
    );
    _ensureOk(response);
  }

  Future<CarPrice> getPrice(int carId) async {
    final response = await http.get(
      _uri('/cars/$carId/price'),
      headers: _headers,
    );
    _ensureOk(response);
    return CarPrice.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<SharedUser>> getShares(int carId) async {
    final response = await http.get(
      _uri('/cars/$carId/shares'),
      headers: _headers,
    );
    _ensureOk(response);
    return SharedUser.listFromJson(response.body);
  }

  Future<List<SharedUser>> shareCar(int carId, int userId) async {
    final response = await http.post(
      _uri('/cars/$carId/shares'),
      headers: _headers,
      body: jsonEncode({'user_id': userId}),
    );
    _ensureOk(response);
    return SharedUser.listFromJson(response.body);
  }

  /// The owner can remove anyone. A shared user can remove themselves.
  Future<void> unshareCar(int carId, int userId) async {
    final response = await http.delete(
      _uri('/cars/$carId/shares/$userId'),
      headers: _headers,
    );
    _ensureOk(response);
  }

  Future<List<Car>> ownedCars() async {
    final user = await me();
    return user.ownedCars;
  }

  /// Superuser only.
  Future<void> renameUser(int userId, String name) async {
    final response = await http.put(
      _uri('/users/$userId'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    _ensureOk(response);
  }

  /// Superuser only.
  Future<int> userToken(int userId) async {
    final response = await http.get(
      _uri('/users/$userId/token'),
      headers: _headers,
    );
    _ensureOk(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['auth_token'] as num).toInt();
  }

  /// Superuser only. Also deletes the cars the user owns.
  Future<void> deleteUser(int userId) async {
    final response = await http.delete(
      _uri('/users/$userId'),
      headers: _headers,
    );
    _ensureOk(response);
  }

  Future<User> createUser({
    required String name,
    required bool isSuperuser,
  }) async {
    final response = await http.post(
      _uri('/users/'),
      headers: _headers,
      body: jsonEncode({'name': name, 'is_superuser': isSuperuser}),
    );
    _ensureOk(response);
    return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Uri _uri(String path) {
    final uri = Uri.tryParse('$baseUrl/v1$path');
    if (uri == null || !uri.hasAuthority) {
      throw ApiException('Invalid server URL: $baseUrl');
    }
    return uri;
  }

  void _ensureOk(http.Response response, {String? action}) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    var message = action ?? 'Request failed';

    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['detail'] is String) {
        message = body['detail'] as String;
      }
    } on FormatException {
      // Keep the generic message when the body is not JSON.
    }

    throw ApiException('$message (${response.statusCode})');
  }
}
