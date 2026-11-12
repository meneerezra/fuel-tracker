import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Measures a GPS trip for one car at a time. Keeps running while the screen
/// is locked through an Android foreground notification.
class TripTracker extends ChangeNotifier {
  TripTracker._();

  static final instance = TripTracker._();

  /// Fixes less accurate than this are ignored, they make the distance jump.
  static const _maxAccuracyMeters = 30.0;

  /// Movement smaller than this is treated as GPS drift. The real threshold
  /// is the accuracy of the fix when that is larger.
  static const _minStepMeters = 5.0;

  StreamSubscription<Position>? _subscription;
  Position? _last;
  int? _carId;
  DateTime? _startedAt;
  double _meters = 0;

  // Debug info, shown on the trip card and in the logs.
  int _fixes = 0;
  int _ignoredFixes = 0;
  double? _lastAccuracy;
  String? _lastError;

  int? get carId => _carId;
  int get fixes => _fixes;
  int get ignoredFixes => _ignoredFixes;
  double? get lastAccuracy => _lastAccuracy;
  String? get lastError => _lastError;
  bool get isTracking => _carId != null;
  double get km => _meters / 1000;
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  /// Starts a trip for [carId]. Throws a [TripException] when location is not
  /// available.
  Future<void> start(int carId) async {
    if (isTracking) throw TripException('A trip is already running');

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    _log('start car=$carId locationService=$serviceEnabled');
    if (!serviceEnabled) {
      throw TripException('Turn on location to track a trip');
    }
    var permission = await Geolocator.checkPermission();
    _log('permission=$permission');
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      _log('permission after request=$permission');
    }
    if (permission == LocationPermission.denied) {
      throw TripException('Location permission is needed to track a trip');
    }
    if (permission == LocationPermission.deniedForever) {
      throw TripException(
        'Location permission is off. Turn it on in the app settings.',
      );
    }

    _carId = carId;
    _startedAt = DateTime.now();
    _meters = 0;
    _last = null;
    _fixes = 0;
    _ignoredFixes = 0;
    _lastAccuracy = null;
    _lastError = null;
    _subscription = Geolocator.getPositionStream(locationSettings: _settings())
        .listen(_onPosition, onError: _onError);
    _log('position stream started');
    notifyListeners();
  }

  /// Stops the trip and returns the driven distance in km.
  double stop() {
    final km = this.km;
    _log(
      'stop km=${km.toStringAsFixed(3)} fixes=$_fixes ignored=$_ignoredFixes',
    );
    // Cancelling throws when the stream never opened, for example after a
    // permission error.
    _subscription?.cancel().catchError((Object error) {
      _log('cancel error: $error');
    });
    _subscription = null;
    _carId = null;
    _startedAt = null;
    _last = null;
    _meters = 0;
    notifyListeners();
    return km;
  }

  void _onPosition(Position position) {
    _fixes++;
    _lastAccuracy = position.accuracy;
    _lastError = null;
    final where =
        '${position.latitude.toStringAsFixed(6)},'
        '${position.longitude.toStringAsFixed(6)} '
        '±${position.accuracy.toStringAsFixed(0)}m '
        'speed=${position.speed.toStringAsFixed(1)}m/s';

    if (position.accuracy > _maxAccuracyMeters) {
      _ignoredFixes++;
      _log(
        'fix #$_fixes $where ignored, less accurate than '
        '${_maxAccuracyMeters.toStringAsFixed(0)}m',
      );
      notifyListeners();
      return;
    }

    final last = _last;
    if (last == null) {
      _log('fix #$_fixes $where first fix, starting point');
      _last = position;
      notifyListeners();
      return;
    }

    final step = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      position.latitude,
      position.longitude,
    );
    // While standing still the position wanders around within the accuracy.
    // Keep the last counted point until the movement is clearly larger, so
    // drift is not counted but slow walking still adds up.
    final threshold = position.accuracy > _minStepMeters
        ? position.accuracy
        : _minStepMeters;
    if (step < threshold) {
      _log(
        'fix #$_fixes $where ${step.toStringAsFixed(1)}m from last point, '
        'below ${threshold.toStringAsFixed(0)}m, waiting',
      );
      notifyListeners();
      return;
    }

    _meters += step;
    _last = position;
    _log(
      'fix #$_fixes $where +${step.toStringAsFixed(1)}m '
      'total=${_meters.toStringAsFixed(1)}m',
    );
    notifyListeners();
  }

  void _onError(Object error) {
    _lastError = error.toString();
    _log('stream error: $error');
    notifyListeners();
  }

  /// Shows up in `flutter run` and `adb logcat -s flutter`.
  static void _log(String message) => debugPrint('[Trip] $message');

  LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        // Every second, the default is every 5 seconds. Drift is filtered in
        // _onPosition, so no distance filter here.
        intervalDuration: const Duration(seconds: 1),
        distanceFilter: 0,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Trip running',
          notificationText: 'Fuel Tracker is measuring your trip',
          notificationChannelName: 'Trip tracking',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );
  }
}

class TripException implements Exception {
  TripException(this.message);

  final String message;

  @override
  String toString() => message;
}
