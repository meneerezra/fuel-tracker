import 'dart:async';

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
    final savedToken = await widget.authStorage.getAuthToken();

    if (!mounted) return;

    _tokenController.text = savedToken ?? '';
    _urlController.text = savedUrl ?? '';
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    final newToken = _tokenController.text.trim();
    final newUrl = _urlController.text.trim();

    await widget.authStorage.saveToken(newToken);
    await widget.storage.saveServerUrl(newUrl);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_save());
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
            ],
          ),
        ),
      ),
    );
  }
}
