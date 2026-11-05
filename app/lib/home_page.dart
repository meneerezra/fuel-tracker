import 'package:flutter/material.dart';
import 'package:fuel_tracker/api.dart';
import 'package:fuel_tracker/secure_storage.dart';
import 'package:fuel_tracker/storage_service.dart';

class HomePage extends StatefulWidget {
  final StorageService storage;
  final AuthStorage authStorage;

  const HomePage({super.key, required this.storage, required this.authStorage});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Car>> _ownedCars;

  @override
  void initState() {
    super.initState();
    _ownedCars = _loadOwnedCars();
  }

  Future<List<Car>> _loadOwnedCars() async {
    final token = await widget.authStorage.getAuthToken();
    if (token == null) throw ApiException('Not logged in');
    final api = Api(baseUrl: widget.storage.getServerUrl(), authToken: token);
    return api.ownedCars();
  }

  Future<void> _refresh() async {
    final future = _loadOwnedCars();
    setState(() {
      _ownedCars = future;
    });
    await future.catchError((_) => <Car>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Car>>(
            future: _ownedCars,
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

              final cars = snapshot.data!;
              if (cars.isEmpty) {
                return ListView(
                  children: const [ListTile(title: Text('No owned cars'))],
                );
              }

              return ListView.builder(
                itemCount: cars.length,
                itemBuilder: (context, index) {
                  final car = cars[index];
                  return ListTile(
                    leading: const Icon(Icons.directions_car),
                    title: Text(car.name),
                    subtitle: Text(
                      '${car.fuelType.value} · '
                      '${car.kmDriven.toStringAsFixed(0)} km driven',
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
