import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fuel_tracker/car_repository.dart';
import 'package:fuel_tracker/cars_page.dart';
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
  CarRepository.init(storage, authStorage);
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
  late int? _currentCarId = widget.storage.getCurrentCarId();
  // Bumped when the home tab opens so it shows the latest car data.
  int _homeReloadToken = 0;

  void _setCurrentCar(int carId) {
    setState(() => _currentCarId = carId);
    widget.storage.saveCurrentCarId(carId);
  }

  Widget animatedIcon(
    IconData icon,
    int index,
    ColorScheme scheme, {
    _NavAnimation animation = _NavAnimation.spin,
  }) {
    final isSelected = currentIndex == index;

    return _NavIcon(
      selected: isSelected,
      animation: animation,
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
      HomePage(
        storage: widget.storage,
        authStorage: widget.authStorage,
        currentCarId: _currentCarId,
        reloadToken: _homeReloadToken,
      ),
      CarsPage(
        storage: widget.storage,
        authStorage: widget.authStorage,
        currentCarId: _currentCarId,
        onCurrentCarChanged: _setCurrentCar,
        isActive: currentIndex == 1,
      ),
      SettingsPage(
        authStorage: widget.authStorage,
        storage: widget.storage,
        mode: widget.mode,
        onModeChanged: widget.onModeChanged,
      ),
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(index: currentIndex, children: pages),
          ),
          const _SyncBanner(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            if (index == 0 && currentIndex != 0) _homeReloadToken++;
            currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: animatedIcon(
              Icons.directions_car_outlined,
              0,
              scheme,
              animation: _NavAnimation.drive,
            ),
            selectedIcon: animatedIcon(
              Icons.directions_car,
              0,
              scheme,
              animation: _NavAnimation.drive,
            ),
            label: 'Current car',
          ),
          NavigationDestination(
            icon: animatedIcon(
              Icons.list_outlined,
              1,
              scheme,
              animation: _NavAnimation.flip,
            ),
            selectedIcon: animatedIcon(
              Icons.list,
              1,
              scheme,
              animation: _NavAnimation.flip,
            ),
            label: 'Cars',
          ),
          NavigationDestination(
            icon: animatedIcon(Icons.settings_outlined, 2, scheme),
            selectedIcon: animatedIcon(Icons.settings, 2, scheme),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

enum _NavAnimation {
  /// Full turn, used for the settings gear.
  spin,

  /// Drives off to the right and comes back in from the left.
  drive,

  /// Flips over vertically like a page.
  flip,
}

/// Nav bar icon that plays its animation each time it gets selected.
class _NavIcon extends StatefulWidget {
  final bool selected;
  final _NavAnimation animation;
  final Widget child;

  const _NavIcon({
    required this.selected,
    required this.animation,
    required this.child,
  });

  @override
  State<_NavIcon> createState() => _NavIconState();
}

class _NavIconState extends State<_NavIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void didUpdateWidget(_NavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        return switch (widget.animation) {
          _NavAnimation.spin => Transform.rotate(
            angle: Curves.easeInOut.transform(t) * 2 * pi,
            child: child,
          ),
          _NavAnimation.drive => ClipRect(
            child: FractionalTranslation(
              translation: Offset(_driveOffset(t), 0),
              child: child,
            ),
          ),
          _NavAnimation.flip => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.003)
              ..rotateX(Curves.easeInOut.transform(t) * 2 * pi),
            child: child,
          ),
        };
      },
    );
  }

  /// Horizontal offset in icon widths: speeds off to the right, then rolls
  /// back in from the left and settles.
  static double _driveOffset(double t) {
    const leaveEnd = 0.4;
    if (t < leaveEnd) {
      return Curves.easeIn.transform(t / leaveEnd) * 1.2;
    }
    final back = Curves.easeOutBack.transform((t - leaveEnd) / (1 - leaveEnd));
    return -1.2 * (1 - back);
  }
}

/// Shows when the server cannot be reached or km changes wait to sync.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner();

  @override
  Widget build(BuildContext context) {
    final repository = CarRepository.instance;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final pending = repository.pendingCount;
        final visible = repository.isOffline || pending > 0;
        final waiting = pending == 1
            ? '1 km change waiting to sync'
            : '$pending km changes waiting to sync';
        final text = repository.isOffline
            ? pending > 0
                  ? 'Offline · $waiting'
                  : 'Offline · showing saved data'
            : repository.isSyncing
            ? 'Syncing km changes...'
            : waiting;

        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: !visible
              ? const SizedBox(width: double.infinity)
              : Material(
                  color: repository.isOffline
                      ? scheme.errorContainer
                      : scheme.secondaryContainer,
                  child: InkWell(
                    // Retry now instead of waiting for the next attempt.
                    onTap: repository.retry,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            repository.isOffline
                                ? Icons.cloud_off
                                : Icons.cloud_sync_outlined,
                            size: 18,
                            color: repository.isOffline
                                ? scheme.onErrorContainer
                                : scheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              text,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: repository.isOffline
                                    ? scheme.onErrorContainer
                                    : scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          if (!repository.isSyncing)
                            Text(
                              'Retry',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: repository.isOffline
                                    ? scheme.onErrorContainer
                                    : scheme.onSecondaryContainer,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
