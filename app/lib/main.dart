import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fuel_tracker/home_page.dart';
import 'package:fuel_tracker/secure_storage.dart';
import 'package:fuel_tracker/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(prefs);
  const secureStorage = FlutterSecureStorage();
  final authStorage = AuthStorage(secureStorage);
  runApp(FuelTrackerApp(storage: storage, authStorage: authStorage));
}

class FuelTracker extends StatefulWidget {
  final ThemeMode mode;
  final StorageService storage;
  final AuthStorage authStorage;

  final ValueChanged<ThemeMode> onModeChanged;
  const FuelTracker({
    super.key,

    required this.storage,
    required this.authStorage,
    required this.mode,
    required this.onModeChanged,
  });

  @override
  State<FuelTracker> createState() => _FuelTrackerState();
}

class FuelTrackerApp extends StatefulWidget {
  final StorageService storage;
  final AuthStorage authStorage;
  const FuelTrackerApp({
    super.key,
    required this.storage,
    required this.authStorage,
  });

  @override
  State<FuelTrackerApp> createState() => _FuelTrackerAppState();
}

class _FuelTrackerAppState extends State<FuelTrackerApp> {
  late ThemeMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.storage.getDarkMode();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fuel Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _mode,
      home: FuelTracker(
        authStorage: widget.authStorage,
        storage: widget.storage,
        mode: _mode,
        onModeChanged: _setMode,
      ),
    );
  }

  void _setMode(ThemeMode mode) {
    setState(() => _mode = mode);
    widget.storage.saveDarkMode(mode);
  }
}

class _FuelTrackerState extends State<FuelTracker> {
  int currentIndex = 0;

  Widget animatedIcon(IconData icon, int index, ColorScheme scheme) {
    final isSelected = currentIndex == index;

    return AnimatedRotation(
      turns: isSelected ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: Icon(
        icon,
        color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final pages = [
      HomePage(storage: widget.storage, authStorage: widget.authStorage),
      SettingsPage(
        authStorage: widget.authStorage,
        storage: widget.storage,
        mode: widget.mode,
        onModeChanged: widget.onModeChanged,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: animatedIcon(Icons.home, 0, scheme),
            selectedIcon: animatedIcon(Icons.home, 0, scheme),
            label: 'Home',
          ),
          NavigationDestination(
            icon: animatedIcon(Icons.settings_outlined, 1, scheme),
            selectedIcon: animatedIcon(Icons.settings, 1, scheme),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
