import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/transit_repository.dart';
import 'travel_preferences.dart';

class TravelPreferencesScreen extends StatefulWidget {
  const TravelPreferencesScreen({super.key});
  @override
  State<TravelPreferencesScreen> createState() =>
      _TravelPreferencesScreenState();
}

class _TravelPreferencesScreenState extends State<TravelPreferencesScreen> {
  TravelPreferences _value = const TravelPreferences();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    TravelPreferencesStore.load().then((value) {
      if (mounted) {
        setState(() {
          _value = value;
          _loading = false;
        });
      }
    });
  }

  Future<PlannerStopOption?> _pick(String title) async {
    final repo = context.read<TransitRepository>();
    return showModalBottomSheet<PlannerStopOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TravelStopPicker(
        title: title,
        repository: repo,
      ),
    );
  }

  Future<void> _setHome() async {
    final value = await _pick('Choose Home');
    if (value != null) {
      setState(() => _value = _value.copyWith(home: value));
      await TravelPreferencesStore.save(_value);
    }
  }

  Future<void> _setWork() async {
    final value = await _pick('Choose Work');
    if (value != null) {
      setState(() => _value = _value.copyWith(work: value));
      await TravelPreferencesStore.save(_value);
    }
  }

  Future<void> _save(TravelPreferences value) async {
    setState(() => _value = value);
    await TravelPreferencesStore.save(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
          appBar: AppBar(title: const Text('Travel preferences')),
          body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Travel preferences')),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text('Home & Work',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Card(
                child: Column(children: [
              ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Home'),
                  subtitle: Text(_value.home?.displayName ?? 'Not set'),
                  onTap: _setHome,
                  trailing: const Icon(Icons.chevron_right)),
              const Divider(height: 1),
              ListTile(
                  leading: const Icon(Icons.work_outline),
                  title: const Text('Work'),
                  subtitle: Text(_value.work?.displayName ?? 'Not set'),
                  onTap: _setWork,
                  trailing: const Icon(Icons.chevron_right)),
            ])),
            const SizedBox(height: 22),
            const Text('Journey preferences',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Card(
                child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: DropdownButtonFormField<DefaultTransport>(
                  initialValue: _value.defaultTransport,
                  decoration: const InputDecoration(
                    labelText: 'Default preferred transport',
                    prefixIcon: Icon(Icons.commute_outlined),
                  ),
                  items: [
                    for (final transport in DefaultTransport.values)
                      DropdownMenuItem(
                        value: transport,
                        child: Text(transport.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _save(_value.copyWith(
                        defaultTransport: value,
                        preferRail: false,
                      ));
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                  title: const Text('Prefer fewer transfers'),
                  subtitle: const Text('Prioritise simpler journeys'),
                  value: _value.preferFewerTransfers,
                  onChanged: (v) =>
                      _save(_value.copyWith(preferFewerTransfers: v))),
              SwitchListTile(
                  title: const Text('Prefer less walking'),
                  subtitle:
                      const Text('Reduce walking distance where possible'),
                  value: _value.preferLessWalking,
                  onChanged: (v) =>
                      _save(_value.copyWith(preferLessWalking: v))),
              SwitchListTile(
                  title: const Text('Accessible mode'),
                  subtitle: const Text(
                      'Highlight lower-transfer, lower-walking options'),
                  value: _value.accessibleMode,
                  onChanged: (v) => _save(_value.copyWith(accessibleMode: v))),
            ])),
            const SizedBox(height: 12),
            const Text(
                'Preferences are stored on this device. The default transport and accessibility choices are used to rank journey recommendations without changing official timetable data.',
                style: TextStyle(fontSize: 12, color: AppTheme.slate)),
          ]),
    );
  }
}

class _TravelStopPicker extends StatefulWidget {
  const _TravelStopPicker({
    required this.title,
    required this.repository,
  });

  final String title;
  final TransitRepository repository;

  @override
  State<_TravelStopPicker> createState() => _TravelStopPickerState();
}

class _TravelStopPickerState extends State<_TravelStopPicker> {
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

  Future<void> _runSearch(String text) async {
    final query = text.trim();
    final requestId = ++_requestId;
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final next = await widget.repository.searchPlannerStops(query, limit: 30);
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
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
                            ? 'Type at least 2 characters to search.'
                            : _searching
                                ? 'Searching…'
                                : 'No matching downloaded stops found.',
                        style: const TextStyle(color: AppTheme.slate),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final option = _results[i];
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
