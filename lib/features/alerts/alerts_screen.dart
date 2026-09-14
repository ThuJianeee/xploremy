import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/transit_repository.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _loading = true;
  List<_AppAlert> _alerts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<TransitRepository>();
    final alerts = <_AppAlert>[];
    final now = DateTime.now();
    for (final op in Operators.all) {
      final last = await repo.lastSync(op.id);
      if (last == null) {
        alerts.add(_AppAlert(
          title: '${op.shortName} is not available offline',
          body: 'Download its official GTFS feed from Offline data before planning with this operator.',
          icon: Icons.cloud_download_outlined,
          severity: _AlertSeverity.info,
        ));
      } else if (now.difference(last) > AppConfig.staticFeedTtl) {
        alerts.add(_AppAlert(
          title: '${op.shortName} timetable may be stale',
          body: 'Last downloaded ${_age(last)}. Refresh the feed for the latest published timetable.',
          icon: Icons.update_outlined,
          severity: _AlertSeverity.warning,
        ));
      }
    }
    if (alerts.isEmpty) {
      alerts.add(const _AppAlert(
        title: 'Offline data is up to date',
        body: 'No local data freshness issues were detected.',
        icon: Icons.check_circle_outline,
        severity: _AlertSeverity.ok,
      ));
    }
    alerts.insert(0, const _AppAlert(
      title: 'Service alerts',
      body: 'XploreMY currently surfaces local data-quality alerts. Operator incident/disruption alerts will appear here when an official supported feed is available.',
      icon: Icons.campaign_outlined,
      severity: _AlertSeverity.info,
    ));
    if (!mounted) return;
    setState(() { _alerts = alerts; _loading = false; });
  }

  static String _age(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    if (diff.inHours > 0) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    return '${diff.inMinutes} minutes ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts Centre')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: _alerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final alert = _alerts[i];
                  final color = switch (alert.severity) {
                    _AlertSeverity.warning => AppTheme.delayed,
                    _AlertSeverity.ok => AppTheme.onTime,
                    _AlertSeverity.info => AppTheme.signalTeal,
                  };
                  return Card(child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: Icon(alert.icon, color: color),
                    title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(alert.body)),
                  ));
                },
              ),
            ),
    );
  }
}

enum _AlertSeverity { info, warning, ok }

class _AppAlert {
  const _AppAlert({required this.title, required this.body, required this.icon, required this.severity});
  final String title;
  final String body;
  final IconData icon;
  final _AlertSeverity severity;
}
