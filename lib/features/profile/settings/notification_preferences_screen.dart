import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../../auth/auth_service.dart';
import 'notification_preferences.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  NotificationPreferences _value = const NotificationPreferences();
  bool _loading = true;

  String get _userId => context.read<AuthService>().user?.id ?? 'guest';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final value = await NotificationPreferencesStore.load(_userId);
    if (!mounted) return;
    setState(() {
      _value = value;
      _loading = false;
    });
  }

  Future<void> _save(NotificationPreferences value) async {
    setState(() => _value = value);
    await NotificationPreferencesStore.save(_userId, value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notification management')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Choose which XploreMY updates you want to receive.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.slate,
                ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.warning_amber_outlined),
                  title: const Text('Service disruption alerts'),
                  subtitle: const Text('Operator notices and disruptions'),
                  value: _value.serviceAlerts,
                  onChanged: (value) =>
                      _save(_value.copyWith(serviceAlerts: value)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.route_outlined),
                  title: const Text('Journey reminders'),
                  subtitle: const Text('Reminders for planned journeys'),
                  value: _value.journeyReminders,
                  onChanged: (value) =>
                      _save(_value.copyWith(journeyReminders: value)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.departure_board_outlined),
                  title: const Text('Departure reminders'),
                  subtitle: const Text('Notify before a saved departure'),
                  value: _value.departureReminders,
                  onChanged: (value) =>
                      _save(_value.copyWith(departureReminders: value)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.emoji_events_outlined),
                  title: const Text('Rewards & missions'),
                  subtitle: const Text('XP, badge and mission updates'),
                  value: _value.rewardUpdates,
                  onChanged: (value) =>
                      _save(_value.copyWith(rewardUpdates: value)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.sync_outlined),
                  title: const Text('Data freshness alerts'),
                  subtitle:
                      const Text('Stale or missing offline feed warnings'),
                  value: _value.dataFreshnessAlerts,
                  onChanged: (value) =>
                      _save(_value.copyWith(dataFreshnessAlerts: value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Reminder timing',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: DropdownButtonFormField<int>(
                initialValue: _value.reminderLeadMinutes,
                decoration: const InputDecoration(
                  labelText: 'Notify me before departure',
                  prefixIcon: Icon(Icons.schedule_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5 minutes before')),
                  DropdownMenuItem(value: 10, child: Text('10 minutes before')),
                  DropdownMenuItem(value: 15, child: Text('15 minutes before')),
                  DropdownMenuItem(value: 30, child: Text('30 minutes before')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _save(_value.copyWith(reminderLeadMinutes: value));
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'These settings manage which notification categories XploreMY should use. Device-level notification permission is still controlled by Android/iOS settings.',
            style: TextStyle(fontSize: 12, color: AppTheme.slate),
          ),
        ],
      ),
    );
  }
}
