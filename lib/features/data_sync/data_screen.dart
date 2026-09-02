import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/transit_repository.dart';

/// Offline data manager — downloads and caches the GTFS-static feeds
/// (SDG 9.c: usable timetables without a data connection).
class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final Map<String, DateTime?> _lastSync = {};
  String? _busyOperator;
  String? _message;

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
    });
    try {
      final result =
          await context.read<TransitRepository>().syncOperator(op, force: true);
      _message = '${op.shortName}: ${result.stops} stops cached.';
    } catch (e) {
      _message = '${op.shortName} failed — $e';
    } finally {
      await _refreshMeta();
      if (mounted) setState(() => _busyOperator = null);
    }
  }

  Future<void> _syncAll() async {
    setState(() => _message = 'Downloading all feeds…');
    final results = await context
        .read<TransitRepository>()
        .syncAll(Operators.all, force: true,
            onProgress: (op) => setState(() => _busyOperator = op.id));
    final ok = results.where((r) => r.ok).length;
    await _refreshMeta();
    if (mounted) {
      setState(() {
        _busyOperator = null;
        _message = '$ok of ${results.length} feeds downloaded.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('d MMM, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline data'),
        actions: [
          IconButton(
            tooltip: 'Download all',
            icon: const Icon(Icons.download_for_offline_outlined),
            onPressed: _busyOperator == null ? _syncAll : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Open data source',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Timetables come from Malaysia\u2019s official data.gov.my GTFS API. '
                    'Static schedules are cached for offline use; supported operators '
                    'also expose live vehicle positions.',
                    style: TextStyle(color: AppTheme.slate, fontSize: 13, height: 1.4),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(_message!,
                        style: const TextStyle(
                            color: AppTheme.signalTeal, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final op in Operators.all)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: Icon(
                    op.id.contains('rail') || op.id == 'ktmb'
                        ? Icons.train_outlined
                        : Icons.directions_bus_outlined,
                    color: AppTheme.trackNavy,
                  ),
                  title: Text(op.shortName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _lastSync[op.id] == null
                        ? 'Not downloaded${op.hasRealtime ? " · live vehicle positions available" : " · schedule only"}'
                        : 'Updated ${formatter.format(_lastSync[op.id]!)}'
                            '${op.hasRealtime ? " · live vehicle positions" : " · schedule only"}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: _busyOperator == op.id
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.download_outlined),
                          onPressed:
                              _busyOperator == null ? () => _sync(op) : null,
                        ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await context.read<TransitRepository>().clearCache();
              await _refreshMeta();
              if (mounted) setState(() => _message = 'Offline cache cleared.');
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear offline cache'),
          ),
        ],
      ),
    );
  }
}
