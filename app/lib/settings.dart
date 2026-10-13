import 'package:flutter/material.dart';
import 'package:fuel_tracker/authentication.dart';
import 'package:fuel_tracker/secure_storage.dart';
import 'package:fuel_tracker/storage_service.dart';

class SettingsPage extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;
  final StorageService storage;
  final AuthStorage authStorage;
  const SettingsPage({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.storage,
    required this.authStorage,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isDarkMode = mode == ThemeMode.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: screenHeight * 0.05),

            Icon(Icons.local_gas_station, size: screenHeight * 0.13),

            const Divider(thickness: 1),
            SwitchListTile(
              value: isDarkMode,
              secondary: Icon(
                isDarkMode ? Icons.dark_mode : Icons.dark_mode_outlined,
              ),
              title: Text('Dark mode'),
              onChanged: (value) {
                onModeChanged(value ? ThemeMode.dark : ThemeMode.light);
              },
            ),
            const Divider(thickness: 1),

            ListTile(
              leading: Icon(Icons.person),
              title: Text('Authentication'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AuthenticationPage(
                      storage: storage,
                      authStorage: authStorage,
                    ),
                  ),
                );
              },
            ),
            const ListTile(
              leading: Icon(Icons.storage),
              title: Text('Server settings'),
            ),
          ],
        ),
      ),
    );
  }
}
