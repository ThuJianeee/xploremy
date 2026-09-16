import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../../../data/models.dart';
import '../../../data/transit_repository.dart';
import '../../auth/auth_service.dart';
import '../../settings/travel_preferences.dart';
import 'saved_addresses.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  bool _loading = true;
  List<SavedAddressEntry> _items = const [];

  String get _userId => context.read<AuthService>().user?.id ?? 'guest';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final items = await SavedAddressStore.load(_userId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _edit([SavedAddressEntry? existing]) async {
    final userId = _userId;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SavedAddressEditScreen(
          userId: userId,
          existing: existing,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _delete(SavedAddressEntry item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete saved address?'),
        content: Text('Remove “${item.label}” from your saved addresses?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await SavedAddressStore.delete(_userId, item.id);
    final prefs = await TravelPreferencesStore.load();
    if (item.role == SavedAddressRole.home) {
      await TravelPreferencesStore.save(prefs.copyWith(clearHome: true));
    } else if (item.role == SavedAddressRole.work) {
      await TravelPreferencesStore.save(prefs.copyWith(clearWork: true));
    }
    await _load();
  }

  IconData _iconFor(SavedAddressRole role) {
    switch (role) {
      case SavedAddressRole.home:
        return Icons.home_outlined;
      case SavedAddressRole.work:
        return Icons.work_outline;
      case SavedAddressRole.other:
        return Icons.place_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  const Text(
                    'Save Home, Work, University or other frequently used stops. Home and Work stay linked with Journey Planner shortcuts.',
                    style: TextStyle(color: AppTheme.slate),
                  ),
                  const SizedBox(height: 14),
                  if (_items.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Column(
                          children: [
                            Icon(Icons.add_location_alt_outlined,
                                size: 48, color: AppTheme.slate),
                            SizedBox(height: 10),
                            Text('No saved addresses yet',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            SizedBox(height: 4),
                            Text(
                              'Add a place to reuse it quickly in your profile and journey planning.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.slate),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final item in _items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0x1400857C),
                              child: Icon(
                                _iconFor(item.role),
                                color: AppTheme.signalTeal,
                              ),
                            ),
                            title: Text(
                              item.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${item.role.label} · ${item.stop.displayName}\n${item.stop.lineName}',
                            ),
                            isThreeLine: true,
                            onTap: () => _edit(item),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _edit(item);
                                if (value == 'delete') _delete(item);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'edit', child: Text('Edit')),
                                PopupMenuItem(
                                    value: 'delete', child: Text('Delete')),
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

class SavedAddressEditScreen extends StatefulWidget {
  const SavedAddressEditScreen({
    super.key,
    required this.userId,
    this.existing,
  });

  final String userId;
  final SavedAddressEntry? existing;

  @override
  State<SavedAddressEditScreen> createState() => _SavedAddressEditScreenState();
}

class _SavedAddressEditScreenState extends State<SavedAddressEditScreen> {
  late final TextEditingController _label;
  late SavedAddressRole _role;
  PlannerStopOption? _stop;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.existing?.label ?? '');
    _role = widget.existing?.role ?? SavedAddressRole.other;
    _stop = widget.existing?.stop;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<PlannerStopOption?> _pickStop() async {
    final repository = context.read<TransitRepository>();
    return showModalBottomSheet<PlannerStopOption>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _SavedAddressStopPicker(repository: repository),
    );
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    final stop = _stop;
    if (label.isEmpty || stop == null || _saving) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a label and choose a stop.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final entry = SavedAddressEntry(
        id: widget.existing?.id ??
            'address_${DateTime.now().microsecondsSinceEpoch}',
        label: label,
        role: _role,
        stop: stop,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      await SavedAddressStore.upsert(widget.userId, entry);

      var preferences = await TravelPreferencesStore.load();
      final oldRole = widget.existing?.role;
      if (oldRole == SavedAddressRole.home && _role != SavedAddressRole.home) {
        preferences = preferences.copyWith(clearHome: true);
      }
      if (oldRole == SavedAddressRole.work && _role != SavedAddressRole.work) {
        preferences = preferences.copyWith(clearWork: true);
      }
      if (_role == SavedAddressRole.home) {
        preferences = preferences.copyWith(home: stop);
      } else if (_role == SavedAddressRole.work) {
        preferences = preferences.copyWith(work: stop);
      }
      await TravelPreferencesStore.save(preferences);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save this address. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null
            ? 'Add saved address'
            : 'Edit saved address'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(
            controller: _label,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'e.g. University, Gym, Parents',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<SavedAddressRole>(
            initialValue: _role,
            decoration: const InputDecoration(
              labelText: 'Address type',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              for (final role in SavedAddressRole.values)
                DropdownMenuItem(value: role, child: Text(role.label)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _role = value);
            },
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(_stop?.displayName ?? 'Choose stop or station'),
              subtitle: _stop == null ? null : Text(_stop!.lineName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final stop = await _pickStop();
                if (stop != null && mounted) setState(() => _stop = stop);
              },
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save address'),
          ),
        ],
      ),
    );
  }
}

class _SavedAddressStopPicker extends StatefulWidget {
  const _SavedAddressStopPicker({required this.repository});

  final TransitRepository repository;

  @override
  State<_SavedAddressStopPicker> createState() =>
      _SavedAddressStopPickerState();
}

class _SavedAddressStopPickerState extends State<_SavedAddressStopPicker> {
  final TextEditingController _search = TextEditingController();
  List<PlannerStopOption> _results = const [];
  bool _searching = false;
  int _requestId = 0;

  @override
  void dispose() {
    _requestId++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    final normalized = query.trim();
    final requestId = ++_requestId;
    if (normalized.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    try {
      final next = await widget.repository.searchPlannerStops(
        normalized,
        limit: 30,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = next;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = const [];
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose stop or station',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: _runSearch,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search station or stop',
              ),
            ),
            const SizedBox(height: 12),
            if (_searching) const LinearProgressIndicator(),
            if (_searching) const SizedBox(height: 8),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _search.text.trim().length < 2
                            ? 'Type at least 2 characters to search downloaded GTFS stops.'
                            : _searching
                                ? 'Searching…'
                                : 'No matching downloaded stops found.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.slate),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (_, index) {
                        final option = _results[index];
                        return ListTile(
                          title: Text(option.displayName),
                          subtitle: Text(option.lineName),
                          onTap: () => Navigator.of(context).pop(option),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
