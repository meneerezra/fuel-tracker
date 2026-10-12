import 'package:flutter/material.dart';

import 'settings.dart';

void main() {
  runApp(const FuelTracker());
}

class FuelTracker extends StatelessWidget {
  const FuelTracker({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Fuel Tracker', home: const HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;

  final List<Widget> pages = [
    const Center(child: Text('Home Page')),
    const SettingsPage(),
  ];

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
