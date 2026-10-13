import 'package:flutter/material.dart';
import 'package:fuel_tracker/authentication.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isDarkMode = false;
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

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
                setState(() => isDarkMode = value);
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
                    builder: (context) => const AuthenticationPage(),
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
