import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/transit_repository.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _loading = true;
  final Map<String, GtfsCacheStats> _health = {};
  List<_ServiceNotice> _notices = const [];
  String? _noticeError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _noticeError = null;
      });
    }

    final repo = context.read<TransitRepository>();
    final health = <String, GtfsCacheStats>{};
    for (final op in Operators.all) {
      health[op.id] = await repo.cacheStats(op.id);
    }

    List<_ServiceNotice> notices = const [];
    String? noticeError;
    try {
      final rows = await Supabase.instance.client
          .from('alerts')
          .select('id,operator_id,title,body,severity,starts_at,ends_at')
          .order('starts_at', ascending: false)
          .limit(30);
      notices = rows.map(_ServiceNotice.fromMap).toList();
    } catch (_) {
      noticeError =
          'Service notice storage is not available yet. Apply the enhanced Supabase SQL to enable operator notices.';
    }

    if (!mounted) return;
    setState(() {
      _health
        ..clear()
        ..addAll(health);
      _notices = notices;
      _noticeError = noticeError;
      _loading = false;
    });
  }

  bool _isStale(DateTime date) {
    return DateTime.now().difference(date) > AppConfig.staticFeedTtl;
  }

  String _age(DateTime? date) {
    if (date == null) return 'Never synced';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inMinutes > 0) return '${diff.inMinutes} min ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service alerts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  const Text(
                    'Service notices',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  if (_noticeError != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.info_outline,
                            color: AppTheme.signalTeal),
                        title: const Text('No service notice feed connected'),
                        subtitle: Text(_noticeError!),
                      ),
                    )
                  else if (_notices.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline,
                            color: AppTheme.onTime),
                        title: Text('No active service notices'),
                        subtitle: Text(
                          'No active operator notices are currently stored in XploreMY.',
                        ),
                      ),
                    )
                  else
                    for (final notice in _notices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _noticeCard(notice),
                      ),
                  const SizedBox(height: 14),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.campaign_outlined,
                          color: AppTheme.signalTeal),
                      title: Text(
                        'Service alerts & feed health',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        'Check operator notices, last sync time, freshness and how much timetable data is cached on this device.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Operator feed health',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  for (final op in Operators.all)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _healthCard(op, _health[op.id]),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _healthCard(Operator op, GtfsCacheStats? stats) {
    final last = stats?.lastSync;
    final missing = last == null;
    final stale = last != null && _isStale(last);
    final status = missing
        ? 'Missing'
        : stale
            ? 'Stale'
            : 'Fresh';
    final color = missing || stale ? AppTheme.delayed : AppTheme.onTime;
    final icon = missing
        ? Icons.cloud_off_outlined
        : stale
            ? Icons.update_outlined
            : Icons.cloud_done_outlined;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    op.shortName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Last sync: ${_age(last)}',
              style: const TextStyle(color: AppTheme.slate),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _metric(
                    'Stops',
                    stats?.stopCount ?? 0,
                    Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metric(
                    'Trips',
                    stats?.tripCount ?? 0,
                    Icons.route_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metric(
                    'Routes',
                    stats?.routeCount ?? 0,
                    Icons.alt_route,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              op.hasRealtime
                  ? 'Realtime vehicle positions supported'
                  : 'Scheduled timetable only',
              style: const TextStyle(fontSize: 12, color: AppTheme.slate),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, int value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.trackNavy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppTheme.trackNavy),
          const SizedBox(height: 3),
          Text(
            '$value',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: AppTheme.slate),
          ),
        ],
      ),
    );
  }

  Widget _noticeCard(_ServiceNotice notice) {
    final color = switch (notice.severity) {
      'critical' => AppTheme.hibiscus,
      'warning' => AppTheme.delayed,
      _ => AppTheme.signalTeal,
    };
    final operatorLabel = notice.operatorId == null
        ? 'All operators'
        : _operatorName(notice.operatorId!);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Icon(Icons.warning_amber_rounded, color: color),
        title: Text(
          notice.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text('$operatorLabel · ${notice.body}'),
        ),
      ),
    );
  }

  String _operatorName(String operatorId) {
    for (final op in Operators.all) {
      if (op.id == operatorId) return op.shortName;
    }
    return operatorId;
  }
}

class _ServiceNotice {
  const _ServiceNotice({
    required this.title,
    required this.body,
    required this.severity,
    this.operatorId,
  });

  final String title;
  final String body;
  final String severity;
  final String? operatorId;

  factory _ServiceNotice.fromMap(Map<String, dynamic> map) {
    return _ServiceNotice(
      title: map['title'] as String? ?? 'Service notice',
      body: map['body'] as String? ?? '',
      severity: map['severity'] as String? ?? 'info',
      operatorId: map['operator_id'] as String?,
    );
  }
}
