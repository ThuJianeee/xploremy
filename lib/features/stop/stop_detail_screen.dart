import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/transit_repository.dart';
import '../auth/auth_service.dart';

/// MODULE 3 — Stop detail / live departures.
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
  CrowdLevel _crowd = CrowdLevel.quiet;
  bool _loading = true;
  bool _isFavourite = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    final repo = context.read<TransitRepository>();
    final auth = context.read<AuthService>();

    final departures = await repo.getDeparturesForStop(
      operatorId: widget.stop.operatorId,
      stopId: widget.stop.stopId,
    );
    final crowd =
        await repo.crowdLevel(widget.stop.operatorId, widget.stop.stopId);
    final shape = departures.isEmpty
        ? <GtfsStop>[]
        : await repo.tripShape(widget.stop.operatorId, departures.first.tripId);
    final vehicles = await repo.liveVehicles(widget.stop.operatorId);

    var favourite = false;
    if (auth.isSignedIn) {
      try {
        final favourites = await auth.favouriteStops();
        favourite = favourites.any((f) => f.stopId == widget.stop.stopId);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _departures = departures;
      _crowd = crowd;
      _shape = shape;
      _vehicles = vehicles;
      _isFavourite = favourite;
      _loading = false;
    });
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final op = Operators.byId(widget.stop.operatorId);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stop.name),
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
                  _header(op),
                  const SizedBox(height: 12),
                  SizedBox(height: 190, child: _map()),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Next departures',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 10),
                  if (_departures.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No more scheduled departures from this stop today.',
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
            Text(op.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.trackNavy)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill(
                  icon: Icons.groups_outlined,
                  label: _crowd.label,
                  color: switch (_crowd) {
                    CrowdLevel.busy => AppTheme.hibiscus,
                    CrowdLevel.moderate => AppTheme.delayed,
                    CrowdLevel.quiet => AppTheme.onTime,
                  },
                ),
                _pill(
                  icon: op.hasRealtime ? Icons.sensors : Icons.schedule,
                  label: op.hasRealtime
                      ? '${_vehicles.length} vehicles live'
                      : 'Scheduled data only',
                  color: op.hasRealtime ? AppTheme.signalTeal : AppTheme.slate,
                ),
              ],
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
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
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
            userAgentPackageName: 'my.xploremy.app',
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
                child: const Icon(Icons.location_on,
                    color: AppTheme.hibiscus, size: 36),
              ),
              for (final v in _vehicles.take(60))
                Marker(
                  point: LatLng(v.lat, v.lon),
                  width: 16,
                  height: 16,
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

class _DepartureTile extends StatelessWidget {
  const _DepartureTile({required this.departure});

  final Departure departure;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = switch (departure.reliability) {
      Reliability.onTime => (AppTheme.onTime, 'On time'),
      Reliability.delayed => (
          AppTheme.delayed,
          'Late by ${formatCountdown(departure.liveDelaySeconds!.abs())}'
        ),
      Reliability.early => (
          AppTheme.signalTeal,
          'Early by ${formatCountdown(departure.liveDelaySeconds!.abs())}'
        ),
      Reliability.scheduled => (AppTheme.slate, 'Scheduled'),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              constraints: const BoxConstraints(minWidth: 56),
              decoration: BoxDecoration(
                color: AppTheme.trackNavy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                departure.routeLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    departure.headsign,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        height: 7,
                        width: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$statusLabel · dep ${formatSecondsOfDay(departure.scheduledSeconds)}',
                        style: TextStyle(fontSize: 12.5, color: statusColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCountdown(departure.secondsUntil),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.trackNavy,
                  ),
                ),
                if (departure.hasLive)
                  const Text('live',
                      style: TextStyle(fontSize: 11, color: AppTheme.signalTeal)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
