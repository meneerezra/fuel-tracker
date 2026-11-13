import 'package:flutter/material.dart';
import 'package:fuel_tracker/api.dart';
import 'package:fuel_tracker/car_repository.dart';
import 'package:fuel_tracker/car_page.dart';
import 'package:fuel_tracker/secure_storage.dart';
import 'package:fuel_tracker/storage_service.dart';

/// Returns the car picked as current car. Falls back to the first owned car,
/// then the first shared car.
Car? pickCurrentCar(User user, int? currentCarId) {
  final cars = [...user.ownedCars, ...user.sharedCars];
  for (final car in cars) {
    if (car.id == currentCarId) return car;
  }
  return cars.isEmpty ? null : cars.first;
}

/// Shows the current car.
class HomePage extends StatefulWidget {
  final StorageService storage;
  final AuthStorage authStorage;
  final int? currentCarId;

  /// Changes when the page should reload, for example when the tab opens.
  final int reloadToken;

  const HomePage({
    super.key,
    required this.storage,
    required this.authStorage,
    required this.currentCarId,
    required this.reloadToken,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? _user;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentCarId != oldWidget.currentCarId ||
        widget.reloadToken != oldWidget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      // Falls back to the saved copy while offline.
      final user = await CarRepository.instance.me();
      if (!mounted) return;
      setState(() {
        _user = user;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    // Keep showing the previous car while a reload is running.
    if (user == null && _error == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final car = user == null ? null : pickCurrentCar(user, widget.currentCarId);
    if (car == null) {
      return Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              children: [
                if (_error != null)
                  ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(_error.toString()),
                  )
                else
                  const ListTile(
                    leading: Icon(Icons.directions_car),
                    title: Text('No cars yet'),
                    subtitle: Text('Add or share a car to see it here'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return CarPage(
      key: ValueKey(car.id),
      car: car,
      storage: widget.storage,
      authStorage: widget.authStorage,
      isOwner: car.ownerId == user!.id,
      userId: user.id,
      onRemoved: _load,
    );
  }
}
