import 'package:flutter/material.dart';
import 'package:fuel_tracker/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

const _themeModeKey = 'themeMode';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(FuelTrackerApp(prefs: prefs));
}

class FuelTrackerApp extends StatefulWidget {
  const FuelTrackerApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<FuelTrackerApp> createState() => _FuelTrackerAppState();
}

class _FuelTrackerAppState extends State<FuelTrackerApp> {
  late ThemeMode _mode = _readMode();

  ThemeMode _readMode() {
    switch (widget.prefs.getString(_themeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void _setMode(ThemeMode mode) {
    setState(() => _mode = mode);
    widget.prefs.setString(_themeModeKey, mode.name);
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
      home: FuelTracker(mode: _mode, onModeChanged: _setMode),
    );
  }
}

class FuelTracker extends StatefulWidget {
  const FuelTracker({
    super.key,
    required this.mode,
    required this.onModeChanged,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;

  @override
  State<FuelTracker> createState() => _FuelTrackerState();
}

class _FuelTrackerState extends State<FuelTracker> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final pages = [
      const HomePage(),
      SettingsPage(mode: widget.mode, onModeChanged: widget.onModeChanged),
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
}
