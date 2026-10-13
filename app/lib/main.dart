import 'package:flutter/material.dart';
import 'package:fuel_tracker/home_page.dart';

import 'settings.dart';

void main() {
  runApp(MaterialApp(title: 'Fuel Tracker', home: const FuelTracker()));
}

class FuelTracker extends StatefulWidget {
  const FuelTracker({super.key});

  @override
  State<FuelTracker> createState() => _FuelTrackerState();
}

class _FuelTrackerState extends State<FuelTracker> {
  int currentIndex = 0;

  final List<Widget> pages = [const HomePage(), const SettingsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        indicatorColor: Colors.blueAccent.withValues(alpha: 0.2),
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: animatedIcon(Icons.home, 0),
            selectedIcon: animatedIcon(Icons.home, 0),
            label: 'Home',
          ),
          NavigationDestination(
            icon: animatedIcon(Icons.settings_outlined, 1),
            selectedIcon: animatedIcon(Icons.settings, 1),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget animatedIcon(IconData icon, int index) {
    final isSelected = currentIndex == index;

    return AnimatedRotation(
      turns: isSelected ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey),
    );
  }
}
