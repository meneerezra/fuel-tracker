import 'package:flutter/material.dart';
import 'package:fuel_tracker/api.dart';
import 'package:fuel_tracker/secure_storage.dart';
import 'package:fuel_tracker/storage_service.dart';

/// Lets the owner share a car by user ID and remove shares.
class ShareCarPage extends StatefulWidget {
  final Car car;
  final StorageService storage;
  final AuthStorage authStorage;

  const ShareCarPage({
    super.key,
    required this.car,
    required this.storage,
    required this.authStorage,
  });

  @override
  State<ShareCarPage> createState() => _ShareCarPageState();
}

class _ShareCarPageState extends State<ShareCarPage> {
  final _userId = TextEditingController();
  List<SharedUser>? _users;
  Object? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _userId.dispose();
    super.dispose();
  }

  Future<Api> _api() async {
    final token = await widget.authStorage.getAuthToken();
    if (token == null) throw ApiException('Not logged in');
    return Api(baseUrl: widget.storage.getServerUrl(), authToken: token);
  }

  Future<void> _load() async {
    try {
      final api = await _api();
      final users = await api.getShares(widget.car.id!);
      if (!mounted) return;
      setState(() {
        _users = users;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Future<void> _share() async {
    final userId = int.tryParse(_userId.text.trim());
    if (userId == null) {
      _showError('Enter a user ID');
      return;
    }
    setState(() => _saving = true);
    try {
      final api = await _api();
      final users = await api.shareCar(widget.car.id!, userId);
      if (!mounted) return;
      _userId.clear();
      setState(() => _users = users);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(SharedUser user) async {
    setState(() => _saving = true);
    try {
      final api = await _api();
      await api.unshareCar(widget.car.id!, user.id);
      if (!mounted) return;
      setState(() => _users = [..._users!]..remove(user));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final users = _users;

    return Scaffold(
      appBar: AppBar(title: Text('Share ${widget.car.name}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _userId,
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _share(),
                      decoration: const InputDecoration(
                        labelText: 'User ID',
                        helperText: 'Found under Settings in their app',
                        prefixIcon: Icon(Icons.person_add_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton(
                      onPressed: _saving ? null : _share,
                      child: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Shared with',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            if (_error != null)
              ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(_error.toString()),
              )
            else if (users == null)
              const Center(child: CircularProgressIndicator())
            else if (users.isEmpty)
              const ListTile(title: Text('Not shared with anyone'))
            else
              for (final user in users)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(user.name ?? 'User ${user.id}'),
                  subtitle: Text('ID ${user.id}'),
                  trailing: IconButton(
                    tooltip: 'Stop sharing',
                    icon: const Icon(Icons.person_remove_outlined),
                    onPressed: _saving ? null : () => _remove(user),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
