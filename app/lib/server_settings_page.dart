import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuel_tracker/api.dart';
import 'package:fuel_tracker/car_page.dart';
import 'package:fuel_tracker/search_field.dart';
import 'package:fuel_tracker/secure_storage.dart';
import 'package:fuel_tracker/storage_service.dart';

/// Superuser page with every account and car on the server.
class ServerSettingsPage extends StatefulWidget {
  final StorageService storage;
  final AuthStorage authStorage;

  const ServerSettingsPage({
    super.key,
    required this.storage,
    required this.authStorage,
  });

  @override
  State<ServerSettingsPage> createState() => _ServerSettingsPageState();
}

class _ServerSettingsPageState extends State<ServerSettingsPage> {
  List<User>? _users;
  int? _myId;
  Object? _error;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<Api> _api() => _createApi(widget.storage, widget.authStorage);

  Future<void> _load() async {
    try {
      final api = await _api();
      final (users, me) = await (api.allUsers(), api.me()).wait;
      if (!mounted) return;
      setState(() {
        // Show your own account first.
        _users = [
          ...users.where((user) => user.id == me.id),
          ...users.where((user) => user.id != me.id),
        ];
        _myId = me.id;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  /// Matches the name, the user ID or the name of one of the user's cars.
  bool _matches(User user) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return _displayName(user).toLowerCase().contains(query) ||
        '${user.id}' == query ||
        [
          ...user.ownedCars,
          ...user.sharedCars,
        ].any((car) => car.name.toLowerCase().contains(query));
  }

  Future<void> _openUser(User user) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _UserPage(
          user: user,
          isMe: user.id == _myId,
          storage: widget.storage,
          authStorage: widget.authStorage,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _addUser() async {
    final input = await showDialog<_NewUser>(
      context: context,
      builder: (context) => const _AddUserDialog(),
    );
    if (input == null) return;

    try {
      final api = await _api();
      final user = await api.createUser(
        name: input.name,
        isSuperuser: input.isSuperuser,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _TokenDialog(
          title: '${user.name ?? 'User'} added',
          message: 'Give this auth token to the new user to log in.',
          token: user.authToken!,
        ),
      );
      _load();
    } catch (error) {
      if (!mounted) return;
      _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users?.where(_matches).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Server settings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUser,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add user'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchField(
              controller: _search,
              hintText: 'Search name, ID or car',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.error_outline),
                          title: Text(_error.toString()),
                        ),
                      ],
                    )
                  : users == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      // Room for the add button.
                      padding: const EdgeInsets.only(bottom: 88),
                      children: [
                        if (users.isEmpty)
                          const ListTile(title: Text('No accounts found')),
                        for (final user in users)
                          _UserTile(
                            user: user,
                            isMe: user.id == _myId,
                            onTap: () => _openUser(user),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final User user;
  final bool isMe;
  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.isMe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final tile = ListTile(
      leading: _UserAvatar(user: user, isMe: isMe),
      title: _UserName(user: user, isMe: isMe),
      subtitle: Text(
        [
          'ID ${user.id}',
          if (user.isSuperuser) 'Superuser',
          '${user.ownedCars.length} owned',
          '${user.sharedCars.length} shared',
        ].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );

    if (!isMe) return tile;
    // Highlight your own account.
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.4),
      clipBehavior: Clip.antiAlias,
      child: tile,
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final User user;
  final bool isMe;
  final double radius;

  const _UserAvatar({required this.user, required this.isMe, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return CircleAvatar(
      radius: radius,
      backgroundColor: isMe ? scheme.primary : scheme.surfaceContainerHighest,
      foregroundColor: isMe ? scheme.onPrimary : scheme.onSurfaceVariant,
      child: Icon(
        user.isSuperuser ? Icons.admin_panel_settings : Icons.person_outline,
        size: radius,
      ),
    );
  }
}

/// The user's name with a "You" badge on your own account.
class _UserName extends StatelessWidget {
  final User user;
  final bool isMe;
  final TextStyle? style;

  const _UserName({required this.user, required this.isMe, this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Flexible(
          child: Text(
            _displayName(user),
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'You',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onPrimary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One account with its actions and cars.
class _UserPage extends StatefulWidget {
  final User user;
  final bool isMe;
  final StorageService storage;
  final AuthStorage authStorage;

  const _UserPage({
    required this.user,
    required this.isMe,
    required this.storage,
    required this.authStorage,
  });

  @override
  State<_UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<_UserPage> {
  late User _user = widget.user;

  Future<Api> _api() => _createApi(widget.storage, widget.authStorage);

  Future<void> _reload() async {
    try {
      final api = await _api();
      final users = await api.allUsers();
      if (!mounted) return;
      setState(() => _user = users.firstWhere((user) => user.id == _user.id));
    } catch (error) {
      if (!mounted) return;
      _showError(context, error);
    }
  }

  Future<void> _openCar(Car car) async {
    // Superusers have owner rights on every car.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarPage(
          car: car,
          storage: widget.storage,
          authStorage: widget.authStorage,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _rename() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(initial: _user.name ?? ''),
    );
    if (name == null) return;
    try {
      final api = await _api();
      await api.renameUser(_user.id, name);
      await _reload();
    } catch (error) {
      if (!mounted) return;
      _showError(context, error);
    }
  }

  Future<void> _showToken() async {
    try {
      final api = await _api();
      final token = await api.userToken(_user.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _TokenDialog(
          title: 'Auth token',
          message:
              'Anyone with this token can log in as '
              '${_displayName(_user)}. Only share it with them.',
          token: token,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(context, error);
    }
  }

  Future<void> _delete() async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_displayName(_user)}?'),
        content: Text(
          _user.ownedCars.isEmpty
              ? 'The account is removed. This cannot be undone.'
              : 'The account and its ${_user.ownedCars.length} owned car(s) '
                    'are removed, also for everyone they are shared with. '
                    'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final api = await _api();
      await api.deleteUser(_user.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = _user;

    return Scaffold(
      appBar: AppBar(),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  _UserAvatar(user: user, isMe: widget.isMe, radius: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _UserName(
                          user: user,
                          isMe: widget.isMe,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            'ID ${user.id}',
                            if (user.isSuperuser) 'Superuser',
                          ].join(' · '),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: _rename,
            ),
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: const Text('Auth token'),
              subtitle: const Text('View the code to log in'),
              onTap: _showToken,
            ),
            // The server does not allow deleting your own account.
            if (!widget.isMe)
              ListTile(
                iconColor: scheme.error,
                textColor: scheme.error,
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete account'),
                onTap: _delete,
              ),
            _SectionHeader('Owned cars'),
            if (user.ownedCars.isEmpty)
              const ListTile(title: Text('No owned cars')),
            for (final car in user.ownedCars) _carTile(car),
            _SectionHeader('Shared with ${widget.isMe ? 'you' : 'them'}'),
            if (user.sharedCars.isEmpty)
              const ListTile(title: Text('No shared cars')),
            for (final car in user.sharedCars) _carTile(car),
          ],
        ),
      ),
    );
  }

  Widget _carTile(Car car) {
    return ListTile(
      leading: const Icon(Icons.directions_car_outlined),
      title: Text(car.name),
      subtitle: Text('${formatKm(car.kmDriven)} km driven'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openCar(car),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

Future<Api> _createApi(StorageService storage, AuthStorage authStorage) async {
  final token = await authStorage.getAuthToken();
  if (token == null) throw ApiException('Not logged in');
  return Api(baseUrl: storage.getServerUrl(), authToken: token);
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(error.toString())));
}

class _NewUser {
  const _NewUser(this.name, this.isSuperuser);

  final String name;
  final bool isSuperuser;
}

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog();

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _name = TextEditingController();
  bool _isSuperuser = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    Navigator.pop(context, _NewUser(name, _isSuperuser));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add user'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: 'Name', errorText: _error),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Superuser'),
            subtitle: const Text('Can see and change every account and car'),
            value: _isSuperuser,
            onChanged: (value) => setState(() => _isSuperuser = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

String _displayName(User user) => user.name ?? 'User ${user.id}';

class _RenameDialog extends StatefulWidget {
  final String initial;

  const _RenameDialog({required this.initial});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _name = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename account'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: 'Name', errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

/// Shows a user's auth token with a copy button.
class _TokenDialog extends StatelessWidget {
  final String title;
  final String message;
  final int token;

  const _TokenDialog({
    required this.title,
    required this.message,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    final token = '${this.token}';

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 16),
          SelectableText(
            token,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: token));
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Token copied')));
          },
          child: const Text('Copy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
