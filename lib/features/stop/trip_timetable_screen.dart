import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/station_names.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/transit_repository.dart';

class TripTimetableScreen extends StatefulWidget {
  const TripTimetableScreen({
    super.key,
    required this.departure,
    required this.currentStopId,
  });

  final Departure departure;
  final String currentStopId;

  @override
  State<TripTimetableScreen> createState() => _TripTimetableScreenState();
}

class _TripTimetableScreenState extends State<TripTimetableScreen> {
  bool _loading = true;
  String? _error;
  List<TripTimetableEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _serviceDate {
    final exactMidnight = widget.departure.scheduledAt.subtract(
      Duration(seconds: widget.departure.scheduledSeconds),
    );
    return DateTime(
      exactMidnight.year,
      exactMidnight.month,
      exactMidnight.day,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await context.read<TransitRepository>().tripTimetable(
            operatorId: widget.departure.operatorId,
            tripId: widget.departure.tripId,
            serviceDate: _serviceDate,
            currentStopId: widget.currentStopId,
            currentScheduledSeconds: widget.departure.scheduledSeconds,
          );
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Trip timetable could not be loaded from the offline GTFS cache.';
        _loading = false;
      });
    }
  }

  String _clock(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    final nextDay = date.day != _serviceDate.day ? ' +1' : '';
    return '$h:$m$nextDay';
  }

  @override
  Widget build(BuildContext context) {
    final departure = widget.departure;
    return Scaffold(
      appBar: AppBar(title: const Text('Trip timetable')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.trackNavy,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  departure.routeLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  departure.headsign,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Service date: ${_serviceDate.day}/${_serviceDate.month}/${_serviceDate.year}',
                            style: const TextStyle(color: AppTheme.slate),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Trip ID: ${departure.tripId}',
                            style: const TextStyle(
                              color: AppTheme.slate,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Row(
                            children: [
                              Icon(Icons.verified_outlined,
                                  size: 17, color: AppTheme.onTime),
                              SizedBox(width: 6),
                              Text(
                                'Scheduled times from cached official GTFS',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.onTime,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline,
                            color: AppTheme.hibiscus),
                        title: Text(_error!),
                        trailing: TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ),
                    )
                  else if (_entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No timetable rows are available for this trip.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.slate),
                      ),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                        child: Column(
                          children: [
                            for (var i = 0; i < _entries.length; i++)
                              _TimetableRow(
                                entry: _entries[i],
                                timeLabel: _clock(_entries[i].scheduledAt),
                                isCurrent: _entries[i].stop.stopId ==
                                    widget.currentStopId,
                                isLast: i == _entries.length - 1,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _TimetableRow extends StatelessWidget {
  const _TimetableRow({
    required this.entry,
    required this.timeLabel,
    required this.isCurrent,
    required this.isLast,
  });

  final TripTimetableEntry entry;
  final String timeLabel;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              Icon(
                isCurrent ? Icons.radio_button_checked : Icons.circle,
                size: isCurrent ? 18 : 10,
                color: isCurrent ? AppTheme.hibiscus : AppTheme.signalTeal,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 38,
                  color: AppTheme.signalTeal.withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cleanStationName(entry.stop.name),
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                Text(
                  'Stop ${entry.sequence}',
                  style: const TextStyle(
                    color: AppTheme.slate,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          timeLabel,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isCurrent ? AppTheme.hibiscus : AppTheme.trackNavy,
          ),
        ),
      ],
    );
  }
}
