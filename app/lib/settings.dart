import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuel_tracker/api.dart';
import 'package:fuel_tracker/authentication.dart';
import 'package:fuel_tracker/secure_storage.dart';
import 'package:fuel_tracker/server_settings_page.dart';
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
            _AccountSection(storage: storage, authStorage: authStorage),
          ],
        ),
      ),
    );
  }
}

/// Shows the user ID others need to share a car with this user, and the
/// server settings for superusers.
class _AccountSection extends StatefulWidget {
  final StorageService storage;
  final AuthStorage authStorage;

  const _AccountSection({required this.storage, required this.authStorage});

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  late Future<User> _user = _load();

  Future<User> _load() async {
    final token = await widget.authStorage.getAuthToken();
    if (token == null) throw ApiException('Not logged in');
    final api = Api(baseUrl: widget.storage.getServerUrl(), authToken: token);
    return api.me();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User>(
      future: _user,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final idTile = ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: const Text('Your user ID'),
          subtitle: Text(
            user != null
                ? 'Share this so others can share cars with you'
                : snapshot.hasError
                ? snapshot.error.toString()
                : 'Loading...',
          ),
          trailing: user == null
              ? null
              : Text(
                  '${user.id}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
          onTap: () {
            if (user == null) {
              // Retry, for example after logging in.
              setState(() => _user = _load());
              return;
            }
            Clipboard.setData(ClipboardData(text: '${user.id}'));
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('User ID copied')));
          },
        );

        return Column(
          children: [
            idTile,
            if (user != null && user.isSuperuser)
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Server settings'),
                subtitle: const Text('All accounts and cars'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ServerSettingsPage(
                      storage: widget.storage,
                      authStorage: widget.authStorage,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
