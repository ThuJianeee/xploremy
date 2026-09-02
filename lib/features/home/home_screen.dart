import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/geo.dart';
import '../../core/location_service.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/transit_repository.dart';
import '../stop/stop_detail_screen.dart';

/// MODULE 2 — Home / Nearby stops.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LocationResult? _location;
  List<GtfsStop> _stops = const [];
  bool _loading = true;
  bool _mapView = false;
  String? _notice;
  double _radius = AppConfig.nearbyRadiusMetres;
  final Set<String> _operatorFilter = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = context.read<TransitRepository>();
    final location = await LocationService.current();

    final synced = await repo.syncedOperatorIds();

    final stops = await repo.getNearbyStops(
      lat: location.lat,
      lon: location.lon,
      radiusMetres: _radius,
      operatorIds: _operatorFilter.isEmpty ? null : _operatorFilter.toList(),
    );

    if (!mounted) return;
    setState(() {
      _location = location;
      _stops = stops;
      _notice = location.message ??
          (synced.isEmpty
              ? 'No official timetable is cached yet. Open “Offline data” and download the operators you need.'
              : null);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby stops'),
        actions: [
          IconButton(
            tooltip: _mapView ? 'List view' : 'Map view',
            icon: Icon(_mapView ? Icons.view_list_outlined : Icons.map_outlined),
            onPressed: () => setState(() => _mapView = !_mapView),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.my_location),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  _filters(),
                  if (_notice != null) _noticeBar(_notice!),
                  Expanded(
                    child: _stops.isEmpty
                        ? _emptyState()
                        : (_mapView ? _map() : _list()),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _filters() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final op in Operators.all)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(op.shortName),
                selected: _operatorFilter.contains(op.id),
                onSelected: (selected) {
                  setState(() {
                    selected
                        ? _operatorFilter.add(op.id)
                        : _operatorFilter.remove(op.id);
                  });
                  _load();
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.social_distance, size: 18),
              label: Text(formatDistance(_radius)),
              onPressed: () {
                setState(() {
                  _radius = _radius >= 5000 ? 800 : _radius * 2;
                });
                _load();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _noticeBar(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.signalTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppTheme.signalTeal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12.5, color: AppTheme.signalTeal)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.explore_off_outlined, size: 56, color: AppTheme.slate),
        const SizedBox(height: 16),
        Text(
          'No stops within ${formatDistance(_radius)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Widen the search radius, clear the operator filters, or download more operator feeds from the Offline data tab.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.slate),
        ),
      ],
    );
  }

  Widget _list() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: _stops.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _StopCard(
        stop: _stops[i],
        onTap: () => _openStop(_stops[i]),
      ),
    );
  }

  Widget _map() {
    final centre = LatLng(_location!.lat, _location!.lon);
    return FlutterMap(
      options: MapOptions(initialCenter: centre, initialZoom: 14.5),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'my.xploremy.app',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: centre,
              width: 22,
              height: 22,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.signalTeal,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
            for (final stop in _stops)
              Marker(
                point: LatLng(stop.lat, stop.lon),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => _openStop(stop),
                  child: const Icon(Icons.location_on,
                      color: AppTheme.hibiscus, size: 34),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _openStop(GtfsStop stop) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StopDetailScreen(stop: stop)),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({required this.stop, required this.onTap});

  final GtfsStop stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final op = Operators.byId(stop.operatorId);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: AppTheme.trackNavy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  op.id.contains('rail') || op.id == 'ktmb'
                      ? Icons.train_outlined
                      : Icons.directions_bus_outlined,
                  color: AppTheme.trackNavy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      op.shortName,
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.slate),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (stop.distanceMetres != null)
                Text(
                  formatDistance(stop.distanceMetres!),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.signalTeal,
                  ),
                ),
              const Icon(Icons.chevron_right, color: AppTheme.slate),
            ],
          ),
        ),
      ),
    );
  }
}
