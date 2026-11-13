import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fuel_tracker/api.dart';
import 'package:fuel_tracker/secure_storage.dart';
import 'package:fuel_tracker/storage_service.dart';

/// A km change made in the app. Saved on the phone first and sent to the
/// server when it can be reached, so km are never lost while offline.
class KmChange {
  KmChange._(this.id, this.userId, this.carId, this.kind, this.value);

  KmChange.add(int? userId, int carId, double km)
    : this._(_newId(), userId, carId, _add, km);
  KmChange.resetTrip(int? userId, int carId)
    : this._(_newId(), userId, carId, _resetTrip, 0);
  KmChange.setTrip(int? userId, int carId, double km)
    : this._(_newId(), userId, carId, _setTrip, km);
  KmChange.setOdometer(int? userId, int carId, double km)
    : this._(_newId(), userId, carId, _setOdometer, km);

  static const _add = 'add';
  static const _resetTrip = 'resetTrip';
  static const _setTrip = 'setTrip';
  static const _setOdometer = 'setOdometer';

  static int _counter = 0;
  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';

  final String id;

  /// Only synced while this user is logged in. Null syncs with any user.
  final int? userId;
  final int carId;
  final String kind;
  final double value;

  Car applyTo(Car car) => switch (kind) {
    _add => car.copyWith(
      kmDriven: car.kmDriven + value,
      totalKmDriven: car.totalKmDriven + value,
    ),
    _resetTrip => car.copyWith(kmDriven: 0),
    _setTrip => car.copyWith(kmDriven: value),
    _setOdometer => car.copyWith(totalKmDriven: value),
    _ => car,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'car_id': carId,
    'kind': kind,
    'value': value,
  };

  factory KmChange.fromJson(Map<String, dynamic> json) => KmChange._(
    json['id'] as String,
    (json['user_id'] as num?)?.toInt(),
    (json['car_id'] as num).toInt(),
    json['kind'] as String,
    (json['value'] as num).toDouble(),
  );
}

/// Loads the account and cars from the server, or from the phone when the
/// server cannot be reached. Km changes are queued and synced later.
class CarRepository extends ChangeNotifier {
  CarRepository._(this._storage, this._authStorage) {
    final json = _storage.getPendingKmChanges();
    if (json != null) {
      _pending.addAll(
        (jsonDecode(json) as List<dynamic>).map(
          (change) => KmChange.fromJson(change as Map<String, dynamic>),
        ),
      );
    }
  }

  static late final CarRepository instance;

  static void init(StorageService storage, AuthStorage authStorage) {
    instance = CarRepository._(storage, authStorage);
    unawaited(instance.sync());
  }

  static const _retryInterval = Duration(seconds: 30);

  final StorageService _storage;
  final AuthStorage _authStorage;
  final List<KmChange> _pending = [];
  bool _offline = false;
  Future<void>? _sync;
  Timer? _retry;

  /// True when the last request could not reach the server.
  bool get isOffline => _offline;
  int get pendingCount => _pending.length;

  Future<Api> api() async {
    final token = await _authStorage.getAuthToken();
    if (token == null) throw ApiException('Not logged in');
    return Api(baseUrl: _storage.getServerUrl(), authToken: token);
  }

  /// The logged in user. Falls back to the saved copy while offline.
  Future<User> me() async {
    try {
      final user = await (await api()).me();
      await _storage.saveCachedUser(jsonEncode(user.toJson()));
      _setOffline(false);
      unawaited(sync());
      return _withPending(user);
    } on OfflineException {
      _setOffline(true);
      final cached = _cachedUser();
      if (cached == null) rethrow;
      return _withPending(cached);
    }
  }

  Future<Car> getCar(int carId) async {
    try {
      final car = await (await api()).getCar(carId);
      _setOffline(false);
      await _updateCachedCar(car);
      return applyPending(car);
    } on OfflineException {
      _setOffline(true);
      final cached = _cachedUser();
      final car = [
        ...?cached?.ownedCars,
        ...?cached?.sharedCars,
      ].where((car) => car.id == carId).firstOrNull;
      if (car == null) rethrow;
      return applyPending(car);
    }
  }

  Future<CarPrice> getPrice(int carId) async {
    try {
      final price = await (await api()).getPrice(carId);
      _setOffline(false);
      await _storage.saveCachedPrice(carId, jsonEncode(price.toJson()));
      return price;
    } on OfflineException {
      _setOffline(true);
      final json = _storage.getCachedPrice(carId);
      if (json == null) rethrow;
      return CarPrice.fromJson(jsonDecode(json) as Map<String, dynamic>);
    }
  }

  /// Saves the change on the phone, then tries to send it. Returns the car
  /// with the change applied. Works offline.
  Future<Car> changeKm(Car car, KmChange change) async {
    _pending.add(change);
    await _savePending();
    notifyListeners();
    unawaited(sync());
    return change.applyTo(car);
  }

  /// Applies km changes that are not on the server yet.
  Car applyPending(Car car) {
    var result = car;
    for (final change in _pending) {
      if (change.carId == car.id) result = change.applyTo(result);
    }
    return result;
  }

  /// Call after the server returned a new version of the car, so the offline
  /// copy stays up to date.
  Future<void> carSaved(Car car) => _updateCachedCar(car);

  bool hasPending(int carId) => _pending.any((change) => change.carId == carId);

  /// Sends queued km changes to the server, oldest first. Returns the running
  /// sync when one is busy.
  Future<void> sync() {
    if (_pending.isEmpty) return Future.value();
    return _sync ??= _runSync().whenComplete(() => _sync = null);
  }

  Future<void> _runSync() async {
    notifyListeners();
    try {
      final api = await this.api();
      final me = await api.me();
      final mine = _pending
          .where((change) => change.userId == null || change.userId == me.id)
          .toList();
      final carIds = {for (final change in mine) change.carId};

      for (final carId in carIds) {
        final changes = mine.where((change) => change.carId == carId).toList();
        try {
          // Apply on top of the latest server version, not the cached one.
          var car = await api.getCar(carId);
          for (final change in changes) {
            car = change.applyTo(car);
          }
          final saved = await api.editCar(
            id: carId,
            name: car.name,
            kmThreshold: car.kmTreshold,
            kmDriven: car.kmDriven,
            totalKmDriven: car.totalKmDriven,
            consumption: car.consumption,
            fuelType: car.fuelType,
            countryCode: car.countryCode,
          );
          await _updateCachedCar(saved);
        } on OfflineException {
          rethrow;
        } on ApiException catch (error) {
          // The car was deleted or is no longer ours. These changes can never
          // be applied, so drop them.
          debugPrint('Dropping ${changes.length} km change(s): $error');
        }
        _pending.removeWhere(changes.contains);
        await _savePending();
      }
      _setOffline(false);
    } on OfflineException {
      _setOffline(true);
    } catch (error) {
      debugPrint('Sync failed: $error');
    } finally {
      _scheduleRetry();
      notifyListeners();
    }
  }

  bool get isSyncing => _sync != null;

  /// Syncs queued km changes, or checks if the server is reachable again.
  Future<void> retry() async {
    if (_pending.isNotEmpty) return sync();
    try {
      await me();
    } catch (_) {
      // Shown through isOffline.
    }
  }

  /// Forgets the saved account, for example after logging in with another
  /// token. Queued km changes are kept and sync when that user logs in again.
  Future<void> clearCache() => _storage.clearCache();

  /// Retries every 30 seconds while offline or while km changes wait.
  void _scheduleRetry() {
    if (_pending.isEmpty && !_offline) {
      _retry?.cancel();
      _retry = null;
    } else {
      _retry ??= Timer.periodic(_retryInterval, (_) => retry());
    }
  }

  void _setOffline(bool offline) {
    if (_offline == offline) return;
    _offline = offline;
    _scheduleRetry();
    notifyListeners();
  }

  User? _cachedUser() {
    final json = _storage.getCachedUser();
    if (json == null) return null;
    return User.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  User _withPending(User user) => user.copyWith(
    ownedCars: user.ownedCars.map(applyPending).toList(),
    sharedCars: user.sharedCars.map(applyPending).toList(),
  );

  Future<void> _updateCachedCar(Car car) async {
    final cached = _cachedUser();
    if (cached == null) return;
    List<Car> replace(List<Car> cars) => [
      for (final old in cars) old.id == car.id ? car : old,
    ];
    final updated = cached.copyWith(
      ownedCars: replace(cached.ownedCars),
      sharedCars: replace(cached.sharedCars),
    );
    await _storage.saveCachedUser(jsonEncode(updated.toJson()));
  }

  Future<void> _savePending() => _storage.savePendingKmChanges(
    jsonEncode([for (final change in _pending) change.toJson()]),
  );
}
