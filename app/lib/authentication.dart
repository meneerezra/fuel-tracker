import 'package:flutter/material.dart';
import 'package:fuel_tracker/secure_storage.dart';
import 'package:fuel_tracker/storage_service.dart';

class AuthenticationPage extends StatefulWidget {
  final StorageService storage;
  final AuthStorage authStorage;
  const AuthenticationPage({
    super.key,
    required this.storage,
    required this.authStorage,
  });

  @override
  State<AuthenticationPage> createState() => _AuthenticationPageState();
}

class _AuthenticationPageState extends State<AuthenticationPage> {
  String? url;
  String? token;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final savedUrl = widget.storage.getServerUrl();
    final savedToken = await widget.authStorage.getAuthToken();

    if (!mounted) return;

    setState(() {
      url = savedUrl;
      token = savedToken;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentication')),
      body: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: const Text('Auth Token'),
              subtitle: Text(
                token == null || token!.isEmpty
                    ? 'No auth token set'
                    : 'Auth token configured',
              ),
              onTap: () {
                final controller = TextEditingController(text: token);

                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Auth Token'),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: '1234567891234567',
                          labelText: 'Sixteen digit token',
                        ),
                        keyboardType: TextInputType.text,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final newToken = controller.text.trim();

                            setState(() {
                              token = newToken;
                            });
                            widget.authStorage.saveToken(newToken);

                            Navigator.pop(context);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            ListTile(
              title: const Text('Server URL'),
              subtitle: Text(url ?? 'The URL of the host server'),
              onTap: () {
                final controller = TextEditingController(text: url);

                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Server URL'),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'https://example.com',
                          labelText: 'URL',
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final newUrl = controller.text.trim();

                            setState(() {
                              url = newUrl;
                            });
                            widget.storage.saveServerUrl(newUrl);

                            Navigator.pop(context);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
