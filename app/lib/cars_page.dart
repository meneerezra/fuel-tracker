import 'package:flutter/material.dart';
import 'package:fuel_tracker/add_car_page.dart';
import 'package:fuel_tracker/api.dart';
import 'package:fuel_tracker/car_page.dart';
import 'package:fuel_tracker/home_page.dart';
import 'package:fuel_tracker/secure_storage.dart';
import 'package:fuel_tracker/storage_service.dart';

/// Lists owned and shared cars. The star picks the current car.
class CarsPage extends StatefulWidget {
  final StorageService storage;
  final AuthStorage authStorage;
  final int? currentCarId;
  final ValueChanged<int> onCurrentCarChanged;

  const CarsPage({
    super.key,
    required this.storage,
    required this.authStorage,
    required this.currentCarId,
    required this.onCurrentCarChanged,
  });

  @override
  State<CarsPage> createState() => _CarsPageState();
}

class _CarsPageState extends State<CarsPage> {
  late Future<User> _user;

  @override
  void initState() {
    super.initState();
    _user = _loadUser();
  }

  Future<User> _loadUser() async {
    final token = await widget.authStorage.getAuthToken();
    if (token == null) throw ApiException('Not logged in');
    final api = Api(baseUrl: widget.storage.getServerUrl(), authToken: token);
    return api.me();
  }

  Future<void> _refresh() async {
    final future = _loadUser();
    setState(() {
      _user = future;
    });
    await future.then((_) {}, onError: (_) {});
  }

  Future<void> _addCar() async {
    final car = await Navigator.push<Car>(
      context,
      MaterialPageRoute(
        builder: (context) => AddCarPage(
          storage: widget.storage,
          authStorage: widget.authStorage,
        ),
      ),
    );
    if (car != null && mounted) _refresh();
  }

  Future<void> _openCar(
    Car car, {
    required bool isOwner,
    required int userId,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarPage(
          car: car,
          storage: widget.storage,
          authStorage: widget.authStorage,
          isOwner: isOwner,
          userId: userId,
        ),
      ),
    );
    // The car may have changed on its page.
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCar,
        icon: const Icon(Icons.add),
        label: const Text('Add car'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<User>(
            future: _user,
            builder: (context, snapshot) {
              // Keep showing the previous result while a refresh is running.
              if (!snapshot.hasData && !snapshot.hasError) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: Text(snapshot.error.toString()),
                    ),
                  ],
                );
              }

              final user = snapshot.data!;
              final currentCarId = pickCurrentCar(
                user,
                widget.currentCarId,
              )?.id;

              return ListView(
                // Room for the add button.
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  _SectionHeader('Owned'),
                  if (user.ownedCars.isEmpty)
                    const ListTile(title: Text('No owned cars')),
                  for (final car in user.ownedCars)
                    _CarTile(
                      car: car,
                      isCurrent: car.id == currentCarId,
                      onTap: () =>
                          _openCar(car, isOwner: true, userId: user.id),
                      onFavorite: () => widget.onCurrentCarChanged(car.id!),
                    ),
                  _SectionHeader('Shared with me'),
                  if (user.sharedCars.isEmpty)
                    const ListTile(title: Text('No shared cars')),
                  for (final car in user.sharedCars)
                    _CarTile(
                      car: car,
                      isCurrent: car.id == currentCarId,
                      onTap: () =>
                          _openCar(car, isOwner: false, userId: user.id),
                      onFavorite: () => widget.onCurrentCarChanged(car.id!),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _CarTile extends StatelessWidget {
  final Car car;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _CarTile({
    required this.car,
    required this.isCurrent,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: const Icon(Icons.directions_car),
      title: Text(car.name),
      subtitle: Text(
        '${car.fuelType.value} · '
        '${car.kmDriven.toStringAsFixed(0)} km driven',
      ),
      trailing: IconButton(
        tooltip: isCurrent ? 'Current car' : 'Set as current car',
        icon: Icon(
          isCurrent ? Icons.star : Icons.star_border,
          color: isCurrent ? scheme.primary : null,
        ),
        onPressed: onFavorite,
      ),
      onTap: onTap,
    );
  }
}
