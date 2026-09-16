import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config.dart';
import '../../../core/station_names.dart';
import '../../../core/theme.dart';
import '../../../data/transit_repository.dart';
import '../../auth/auth_service.dart';
import '../../planner/planner_history.dart';
import '../../planner/planner_saved.dart';
import '../../planner/route_planner_screen.dart';
import '../../stop/stop_detail_screen.dart';
import 'favorites_folder_store.dart';

class FavoritesFoldersScreen extends StatefulWidget {
  const FavoritesFoldersScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<FavoritesFoldersScreen> createState() => _FavoritesFoldersScreenState();
}

class _FavoritesFoldersScreenState extends State<FavoritesFoldersScreen> {
  bool _loading = true;
  List<FavoriteFolder> _folders = const [];

  String get _userId => widget.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final folders = await FavoritesFolderStore.load(_userId);
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _loading = false;
    });
  }

  Future<String?> _askName({String initial = ''}) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => _FolderNameDialog(initial: initial),
    );
  }

  Future<void> _createFolder() async {
    final name = await _askName();
    if (name == null || name.isEmpty) return;
    final folders = await FavoritesFolderStore.create(_userId, name);
    if (!mounted) return;
    setState(() => _folders = folders);
  }

  Future<void> _renameFolder(FavoriteFolder folder) async {
    final name = await _askName(initial: folder.name);
    if (name == null || name.isEmpty || name == folder.name) return;
    final folders = await FavoritesFolderStore.rename(_userId, folder.id, name);
    if (!mounted) return;
    setState(() => _folders = folders);
  }

  Future<void> _deleteFolder(FavoriteFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'Delete “${folder.name}” and remove its ${folder.items.length} saved item${folder.items.length == 1 ? '' : 's'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 44),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final folders = await FavoritesFolderStore.delete(_userId, folder.id);
    if (!mounted) return;
    setState(() => _folders = folders);
  }

  Future<void> _openFolder(FavoriteFolder folder) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FavoriteFolderDetailScreen(
          userId: _userId,
          folderId: folder.id,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites folders'),
        actions: [
          IconButton(
            tooltip: 'Create folder',
            onPressed: _createFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createFolder,
        icon: const Icon(Icons.add),
        label: const Text('New folder'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.folder_copy_outlined,
                          color: AppTheme.signalTeal),
                      title: Text(
                        'Organize your commute',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Create folders and keep both favorite stops and saved planned journeys together.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_folders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.folder_open_outlined,
                              size: 52, color: AppTheme.slate),
                          SizedBox(height: 12),
                          Text(
                            'No favorites folders yet',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Create one for daily commute, weekend trips, campus travel, or any collection you like.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.slate),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final folder in _folders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0x1400857C),
                              child: Icon(Icons.folder_outlined,
                                  color: AppTheme.signalTeal),
                            ),
                            title: Text(
                              folder.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${folder.items.length} saved item${folder.items.length == 1 ? '' : 's'}',
                            ),
                            onTap: () => _openFolder(folder),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'rename') _renameFolder(folder);
                                if (value == 'delete') _deleteFolder(folder);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Rename'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({required this.initial});

  final String initial;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial.trim();
  }

  void _submit() {
    final value = _value.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial.isEmpty ? 'Create favorites folder' : 'Rename folder',
      ),
      content: TextFormField(
        initialValue: widget.initial,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Folder name',
          hintText: 'e.g. Daily Commute',
        ),
        onChanged: (value) => _value = value,
        onFieldSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(88, 44),
          ),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class FavoriteFolderDetailScreen extends StatefulWidget {
  const FavoriteFolderDetailScreen({
    super.key,
    required this.userId,
    required this.folderId,
  });

  final String userId;
  final String folderId;

  @override
  State<FavoriteFolderDetailScreen> createState() =>
      _FavoriteFolderDetailScreenState();
}

class _FavoriteFolderDetailScreenState
    extends State<FavoriteFolderDetailScreen> {
  FavoriteFolder? _folder;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final folders = await FavoritesFolderStore.load(widget.userId);
    FavoriteFolder? folder;
    for (final candidate in folders) {
      if (candidate.id == widget.folderId) {
        folder = candidate;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _folder = folder;
      _loading = false;
    });
  }

  Future<void> _showAddItems() async {
    final auth = context.read<AuthService>();
    final savedJourneys = await PlannerSavedStore.load();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              const Text(
                'Add to folder',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              const Text(
                'Favorite stops',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (auth.favourites.isEmpty)
                const Text(
                  'No favorite stops yet. Star a stop first.',
                  style: TextStyle(color: AppTheme.slate),
                )
              else
                for (final stop in auth.favourites)
                  ListTile(
                    leading: const Icon(Icons.star_outline),
                    title: Text(cleanStationName(stop.stopName)),
                    subtitle: Text(Operators.byId(stop.operatorId).shortName),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () async {
                      await _addStop(stop);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                  ),
              const Divider(height: 28),
              const Text(
                'Saved planned journeys',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (savedJourneys.isEmpty)
                const Text(
                  'No saved journeys yet. Save a route in Journey Planner first.',
                  style: TextStyle(color: AppTheme.slate),
                )
              else
                for (final journey in savedJourneys)
                  ListTile(
                    leading: const Icon(Icons.route_outlined),
                    title: Text('${journey.fromName} → ${journey.toName}'),
                    subtitle: const Text('Saved journey'),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () async {
                      await _addJourney(journey);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                  ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addStop(FavouriteStop stop) async {
    await FavoritesFolderStore.addItem(
      widget.userId,
      widget.folderId,
      FavoriteFolderItem(
        id: 'stop:${stop.operatorId}:${stop.stopId}',
        type: 'stop',
        title: cleanStationName(stop.stopName),
        subtitle: Operators.byId(stop.operatorId).shortName,
        payload: {
          'operatorId': stop.operatorId,
          'stopId': stop.stopId,
          'stopName': stop.stopName,
        },
      ),
    );
    await _load();
  }

  Future<void> _addJourney(PlannerHistoryEntry journey) async {
    await FavoritesFolderStore.addItem(
      widget.userId,
      widget.folderId,
      FavoriteFolderItem(
        id: 'journey:${journey.key}',
        type: 'journey',
        title: '${journey.fromName} → ${journey.toName}',
        subtitle: 'Planned journey',
        payload: {'entry': journey.toMap()},
      ),
    );
    await _load();
  }

  Future<void> _removeItem(FavoriteFolderItem item) async {
    await FavoritesFolderStore.removeItem(
      widget.userId,
      widget.folderId,
      item.id,
    );
    await _load();
  }

  Future<void> _openItem(FavoriteFolderItem item) async {
    if (item.type == 'stop') {
      final operatorId = item.payload['operatorId'] as String?;
      final stopId = item.payload['stopId'] as String?;
      if (operatorId == null || stopId == null) return;
      final stop = await context.read<TransitRepository>().getStop(
            operatorId,
            stopId,
          );
      if (!mounted) return;
      if (stop == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This stop is not available in the offline cache.'),
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StopDetailScreen(stop: stop)),
      );
      return;
    }

    final rawEntry = item.payload['entry'];
    if (rawEntry is! Map) return;
    final entry = PlannerHistoryEntry.fromMap(
      Map<String, dynamic>.from(rawEntry),
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoutePlannerScreen(initialJourney: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folder = _folder;
    return Scaffold(
      appBar: AppBar(title: Text(folder?.name ?? 'Favorites folder')),
      floatingActionButton: folder == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddItems,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : folder == null
              ? const Center(child: Text('Folder no longer exists.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      if (folder.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(28),
                          child: Column(
                            children: [
                              Icon(Icons.bookmark_add_outlined,
                                  size: 50, color: AppTheme.slate),
                              SizedBox(height: 12),
                              Text(
                                'This folder is empty',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Add a favorite stop or a saved planned journey.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.slate),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final item in folder.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Icon(
                                    item.type == 'stop'
                                        ? Icons.location_on_outlined
                                        : Icons.route_outlined,
                                  ),
                                ),
                                title: Text(item.title),
                                subtitle: Text(item.subtitle),
                                onTap: () => _openItem(item),
                                trailing: IconButton(
                                  tooltip: 'Remove from folder',
                                  onPressed: () => _removeItem(item),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}
