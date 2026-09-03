import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/transit_repository.dart';
import '../../widgets/status_banner.dart';

/// Offline data manager — downloads and caches GTFS-static feeds.
class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final Map<String, DateTime?> _lastSync = {};
  String? _busyOperator;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _refreshMeta();
  }

  Future<void> _refreshMeta() async {
    final repo = context.read<TransitRepository>();
    for (final op in Operators.all) {
      _lastSync[op.id] = await repo.lastSync(op.id);
    }
    if (mounted) setState(() {});
  }

  Future<void> _sync(Operator op) async {
    setState(() {
      _busyOperator = op.id;
      _message = null;
      _messageIsError = false;
    });

    try {
      final result = await context
          .read<TransitRepository>()
          .syncOperator(op, force: true);
      _message = '${op.shortName}: ${result.stops} stops cached.';
    } catch (_) {
      _message =
          '${op.shortName} could not be updated. Existing cached data was kept.';
      _messageIsError = true;
    } finally {
      await _refreshMeta();
      if (mounted) setState(() => _busyOperator = null);
    }
  }

  Future<void> _syncAll() async {
    setState(() {
      _message = 'Downloading official timetable feeds…';
      _messageIsError = false;
    });

    final results = await context.read<TransitRepository>().syncAll(
          Operators.all,
          force: true,
          onProgress: (op) {
            if (mounted) setState(() => _busyOperator = op.id);
          },
        );

    final ok = results.where((result) => result.ok).length;
    await _refreshMeta();

    if (!mounted) return;
    setState(() {
      _busyOperator = null;
      _message = '$ok of ${results.length} feeds downloaded.';
      _messageIsError = ok != results.length;
    });
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear offline data?'),
        content: const Text(
          'Downloaded timetables will be removed. You can download them again at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear data'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<TransitRepository>().clearCache();
    await _refreshMeta();
    if (mounted) {
      setState(() {
        _message = 'Offline cache cleared.';
        _messageIsError = false;
      });
    }
  }

  bool _isStale(DateTime date) {
    return DateTime.now().difference(date) > AppConfig.staticFeedTtl;
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('d MMM, HH:mm');
    final busy = _busyOperator != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline data'),
        actions: [
          IconButton(
            tooltip: 'Download all',
            icon: const Icon(Icons.download_for_offline_outlined),
            onPressed: busy ? null : _syncAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshMeta,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Official open transport data',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Static GTFS timetables are downloaded from data.gov.my and stored on this device for offline use. Live vehicle positions are only shown for supported operators.',
                      style: TextStyle(
                        color: AppTheme.slate,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      StatusBanner(
                        message: _message!,
                        color: _messageIsError
                            ? AppTheme.hibiscus
                            : AppTheme.signalTeal,
                        icon: _messageIsError
                            ? Icons.warning_amber_outlined
                            : Icons.info_outline,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final op in Operators.all)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OperatorDataCard(
                  operator: op,
                  lastSync: _lastSync[op.id],
                  stale: _lastSync[op.id] != null && _isStale(_lastSync[op.id]!),
                  formatter: formatter,
                  busy: _busyOperator == op.id,
                  disabled: busy,
                  onDownload: () => _sync(op),
                ),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: busy ? null : _clearCache,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear offline cache'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperatorDataCard extends StatelessWidget {
  const _OperatorDataCard({
    required this.operator,
    required this.lastSync,
    required this.stale,
    required this.formatter,
    required this.busy,
    required this.disabled,
    required this.onDownload,
  });

  final Operator operator;
  final DateTime? lastSync;
  final bool stale;
  final DateFormat formatter;
  final bool busy;
  final bool disabled;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final downloaded = lastSync != null;
    final status = downloaded
        ? 'Updated ${formatter.format(lastSync!)}${stale ? ' · update recommended' : ''}'
        : 'Not downloaded';
    final realtime = operator.hasRealtime
        ? 'Live vehicle positions supported'
        : 'Scheduled timetable only';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Icon(
          operator.isRail ? Icons.train_outlined : Icons.directions_bus_outlined,
          color: AppTheme.trackNavy,
        ),
        title: Text(
          operator.shortName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$status\n$realtime',
          style: TextStyle(
            fontSize: 12.5,
            color: stale ? AppTheme.delayed : null,
          ),
        ),
        isThreeLine: true,
        trailing: busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: downloaded ? 'Update data' : 'Download data',
                icon: Icon(
                  downloaded ? Icons.refresh : Icons.download_outlined,
                ),
                onPressed: disabled ? null : onDownload,
              ),
      ),
    );
  }
}
