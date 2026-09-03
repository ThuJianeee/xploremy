import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/geo.dart';
import '../../core/station_names.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/transit_repository.dart';
import '../../widgets/status_banner.dart';
import '../auth/auth_service.dart';

part 'widgets/departure_tile.dart';

/// Stop details with calendar/frequency-aware departures and live vehicle
/// positions where the official data.gov.my feed supports them.
class StopDetailScreen extends StatefulWidget {
  const StopDetailScreen({super.key, required this.stop});

  final GtfsStop stop;

  @override
  State<StopDetailScreen> createState() => _StopDetailScreenState();
}

class _StopDetailScreenState extends State<StopDetailScreen> {
  List<Departure> _departures = const [];
  List<GtfsStop> _shape = const [];
  List<VehiclePosition> _vehicles = const [];
  bool _loading = true;
  bool _isFavourite = false;
  DateTime? _updatedAt;
  CrowdLevel? _crowd;
  String? _error;
  bool _refreshing = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(quiet: true),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (_refreshing) return;
    _refreshing = true;

    if (!quiet && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final repo = context.read<TransitRepository>();
    final auth = context.read<AuthService>();

    try {
      final departures = await repo.getDeparturesForStop(
        operatorId: widget.stop.operatorId,
        stopId: widget.stop.stopId,
      );
      final shape = departures.isEmpty
          ? <GtfsStop>[]
          : await repo.tripShape(
              widget.stop.operatorId,
              departures.first.tripId,
            );
      final vehicles = await repo.liveVehicles(widget.stop.operatorId);
      final crowd = await repo.crowdLevel(
        widget.stop.operatorId,
        widget.stop.stopId,
      );

      var favourite = false;
      if (auth.isSignedIn) {
        try {
          final favourites = await auth.favouriteStops();
          favourite = favourites.any(
            (item) =>
                item.stopId == widget.stop.stopId &&
                item.operatorId == widget.stop.operatorId,
          );
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _departures = departures;
        _shape = shape;
        _vehicles = vehicles;
        _crowd = crowd;
        _isFavourite = favourite;
        _updatedAt = DateTime.now();
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Stop information could not be refreshed. Pull down to try again.';
        _loading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _toggleFavourite() async {
    final auth = context.read<AuthService>();
    try {
      if (_isFavourite) {
        await auth.removeFavourite(widget.stop.stopId);
      } else {
        await auth.addFavourite(
          stopId: widget.stop.stopId,
          stopName: widget.stop.name,
          operatorId: widget.stop.operatorId,
        );
      }
      if (mounted) setState(() => _isFavourite = !_isFavourite);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final op = Operators.byId(widget.stop.operatorId);

    return Scaffold(
      appBar: AppBar(
        title: Text(cleanStationName(widget.stop.name)),
        actions: [
          IconButton(
            tooltip: _isFavourite ? 'Remove favourite' : 'Save stop',
            icon: Icon(_isFavourite ? Icons.star : Icons.star_border),
            onPressed: _toggleFavourite,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                children: [
                  if (_error != null) ...[
                    StatusBanner(
                      message: _error!,
                      color: AppTheme.hibiscus,
                      icon: Icons.error_outline,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _header(op),
                  const SizedBox(height: 12),
                  SizedBox(height: 190, child: _map()),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Next departures',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (_updatedAt != null)
                          Text(
                            'Updated ${formatClockTime(_updatedAt!)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.slate,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_departures.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No upcoming departures are published for this stop.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.slate),
                      ),
                    )
                  else
                    for (final d in _departures)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DepartureTile(departure: d),
                      ),
                ],
              ),
            ),
    );
  }

  Widget _header(Operator op) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              op.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.trackNavy,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill(
                  icon: Icons.event_available_outlined,
                  label: 'Official GTFS timetable',
                  color: AppTheme.onTime,
                ),
                _pill(
                  icon: op.hasRealtime ? Icons.sensors : Icons.schedule,
                  label: op.hasRealtime
                      ? '${_vehicles.length} vehicles live'
                      : 'Scheduled data only',
                  color: op.hasRealtime ? AppTheme.signalTeal : AppTheme.slate,
                ),
                if (_crowd != null)
                  _pill(
                    icon: Icons.groups_2_outlined,
                    label: 'Typical crowd: ${_crowd!.label}',
                    color: AppTheme.delayed,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              op.hasRealtime
                  ? 'Live markers use the official vehicle-position feed. Departure times remain scheduled because the public API does not currently provide TripUpdates.'
                  : 'This operator does not currently have a stable public realtime vehicle feed, so departures are shown from the official schedule.',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AppTheme.slate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _map() {
    final centre = LatLng(widget.stop.lat, widget.stop.lon);
    final line = _shape.map((s) => LatLng(s.lat, s.lon)).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FlutterMap(
        options: MapOptions(initialCenter: centre, initialZoom: 14),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.xploremy',
          ),
          if (line.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: line,
                  strokeWidth: 4,
                  color: AppTheme.trackNavy.withValues(alpha: 0.7),
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              Marker(
                point: centre,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: AppTheme.hibiscus,
                  size: 36,
                ),
              ),
              for (final v in _vehicles.take(80))
                Marker(
                  point: LatLng(v.lat, v.lon),
                  width: 18,
                  height: 18,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.signalTeal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
