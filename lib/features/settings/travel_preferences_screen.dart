import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/transit_repository.dart';
import 'travel_preferences.dart';

class TravelPreferencesScreen extends StatefulWidget {
  const TravelPreferencesScreen({super.key});
  @override
  State<TravelPreferencesScreen> createState() => _TravelPreferencesScreenState();
}

class _TravelPreferencesScreenState extends State<TravelPreferencesScreen> {
  TravelPreferences _value = const TravelPreferences();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    TravelPreferencesStore.load().then((value) {
      if (mounted) setState(() { _value = value; _loading = false; });
    });
  }

  Future<PlannerStopOption?> _pick(String title) async {
    final repo = context.read<TransitRepository>();
    final controller = TextEditingController();
    var results = <PlannerStopOption>[];
    return showModalBottomSheet<PlannerStopOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) {
        Future<void> search(String text) async {
          if (text.trim().length < 2) { setSheetState(() => results = []); return; }
          final next = await repo.searchPlannerStops(text.trim(), limit: 30);
          if (context.mounted) setSheetState(() => results = next);
        }
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
          child: SizedBox(height: MediaQuery.sizeOf(context).height * 0.72, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: controller, autofocus: true, onChanged: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search station or stop')),
            const SizedBox(height: 12),
            Expanded(child: results.isEmpty ? const Center(child: Text('Type at least 2 characters to search.', style: TextStyle(color: AppTheme.slate))) : ListView.builder(
              itemCount: results.length,
              itemBuilder: (_, i) { final option = results[i]; return ListTile(title: Text(option.displayName), subtitle: Text(option.lineName), onTap: () => Navigator.pop(sheetContext, option)); },
            )),
          ])),
        );
      }),
    );
  }

  Future<void> _setHome() async { final value = await _pick('Choose Home'); if (value != null) { setState(() => _value = _value.copyWith(home: value)); await TravelPreferencesStore.save(_value); } }
  Future<void> _setWork() async { final value = await _pick('Choose Work'); if (value != null) { setState(() => _value = _value.copyWith(work: value)); await TravelPreferencesStore.save(_value); } }
  Future<void> _save(TravelPreferences value) async { setState(() => _value = value); await TravelPreferencesStore.save(value); }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(title: const Text('Travel preferences')), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Travel preferences')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
        const Text('Home & Work', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.home_outlined), title: const Text('Home'), subtitle: Text(_value.home?.displayName ?? 'Not set'), onTap: _setHome, trailing: const Icon(Icons.chevron_right)),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.work_outline), title: const Text('Work'), subtitle: Text(_value.work?.displayName ?? 'Not set'), onTap: _setWork, trailing: const Icon(Icons.chevron_right)),
        ])),
        const SizedBox(height: 22),
        const Text('Journey preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Card(child: Column(children: [
          SwitchListTile(title: const Text('Prefer fewer transfers'), subtitle: const Text('Prioritise simpler journeys'), value: _value.preferFewerTransfers, onChanged: (v) => _save(_value.copyWith(preferFewerTransfers: v))),
          SwitchListTile(title: const Text('Prefer less walking'), subtitle: const Text('Reduce walking distance where possible'), value: _value.preferLessWalking, onChanged: (v) => _save(_value.copyWith(preferLessWalking: v))),
          SwitchListTile(title: const Text('Prefer rail'), subtitle: const Text('Use rail options before buses when comparable'), value: _value.preferRail, onChanged: (v) => _save(_value.copyWith(preferRail: v))),
          SwitchListTile(title: const Text('Accessible mode'), subtitle: const Text('Highlight lower-transfer, lower-walking options'), value: _value.accessibleMode, onChanged: (v) => _save(_value.copyWith(accessibleMode: v))),
        ])),
        const SizedBox(height: 12),
        const Text('Preferences are stored on this device and are used to rank journey choices without changing official timetable data.', style: TextStyle(fontSize: 12, color: AppTheme.slate)),
      ]),
    );
  }
}
