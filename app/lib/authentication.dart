import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuel_tracker/api.dart';
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
  final _tokenController = TextEditingController();
  final _urlController = TextEditingController();
  Timer? _saveTimer;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final savedUrl = widget.storage.getServerUrl();
    final rawToken = await widget.authStorage.getAuthToken();

    _tokenController.text = rawToken?.toString() ?? '';
    _urlController.text = savedUrl ?? '';
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save({bool showError = true}) async {
    final rawToken = _tokenController.text.trim();
    final newUrl = _urlController.text.trim();
    int newToken;

    try {
      newToken = int.parse(rawToken);
    } on Exception {
      _tokenController.text = '';
      if (showError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid auth token. Please enter a valid integer.'),
          ),
        );
      }
      return;
    }

    await widget.authStorage.saveToken(newToken);
    await widget.storage.saveServerUrl(newUrl);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_save(showError: false));
    _tokenController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentication')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  hintText: 'https://example.com',
                  labelText: 'Server URL',
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onChanged: (_) => _scheduleSave(),
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tokenController,
                decoration: InputDecoration(
                  border: const UnderlineInputBorder(),
                  hintText: '1234567891234567',
                  labelText: 'Auth token',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureToken ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscureToken = !_obscureToken),
                    tooltip: _obscureToken ? 'Show token' : 'Hide token',
                  ),
                ),
                obscureText: _obscureToken,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _scheduleSave(),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  final rawUrl = _urlController.text.trim();
                  final token = int.tryParse(_tokenController.text.trim());

                  if (rawUrl.isEmpty) {
                    showAlert('Enter a server URL.');
                    return;
                  }
                  if (token == null) {
                    showAlert('Enter a valid auth token.');
                    return;
                  }

                  final api = Api(baseUrl: rawUrl, authToken: token);
                  try {
                    await api.me();
                    if (!mounted) return;
                    showAlert('Connection succeeded.');
                  } catch (e) {
                    if (!mounted) return;
                    showAlert('Connection failed: $e');
                  }
                },
                child: Text("Test connection"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showAlert(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
