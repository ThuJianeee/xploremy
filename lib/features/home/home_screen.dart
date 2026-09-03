import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/geo.dart';
import '../../core/location_service.dart';
import '../../core/station_names.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/transit_repository.dart';
import '../../widgets/status_banner.dart';
import '../stop/stop_detail_screen.dart';
import 'widgets/stop_card.dart';

enum _StopTypeFilter { all, rail, bus }
enum _StopSort { distance, name, operator }

/// MODULE 2 — Home / Nearby stops.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  final Set<String> _operatorFilter = {};

  LocationResult? _location;
  List<GtfsStop> _stops = const [];
  bool _loading = true;
  bool _mapView = false;
  String? _notice;
  String? _error;
  double _radius = AppConfig.nearbyRadiusMetres;
  _StopTypeFilter _typeFilter = _StopTypeFilter.all;
  _StopSort _sort = _StopSort.distance;

  @override
  void initState() {
    super.initState();
    _search.addListener(_refreshView);
    _load();
  }

  @override
  void dispose() {
    _search
      ..removeListener(_refreshView)
      ..dispose();
    super.dispose();
  }

  void _refreshView() => setState(() {});

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final repo = context.read<TransitRepository>();
      final location = await LocationService.current();
      final synced = await repo.syncedOperatorIds();
      final stops = await repo.getNearbyStops(
        lat: location.lat,
        lon: location.lon,
        radiusMetres: _radius,
        operatorIds: _operatorFilter.isEmpty ? null : _operatorFilter.toList(),
        limit: 80,
      );

      if (!mounted) return;
      setState(() {
        _location = location;
        _stops = stops;
        _notice = location.message ??
            (synced.isEmpty
                ? 'No official timetable is cached yet. Open Offline data and download the operators you need.'
                : null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Nearby stops could not be loaded. Check location access and try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<GtfsStop> get _visibleStops {
    final query = _search.text.trim().toLowerCase();
    final result = _stops.where((stop) {
      final op = Operators.byId(stop.operatorId);
      final isRail = op.isRail || op.id.contains('rail');
      final matchesType = switch (_typeFilter) {
        _StopTypeFilter.all => true,
        _StopTypeFilter.rail => isRail,
        _StopTypeFilter.bus => !isRail,
      };
      final matchesQuery = query.isEmpty ||
          cleanStationName(stop.name).toLowerCase().contains(query) ||
          op.shortName.toLowerCase().contains(query);
      return matchesType && matchesQuery;
    }).toList();

    result.sort((a, b) {
      switch (_sort) {
        case _StopSort.name:
          return cleanStationName(a.name)
              .toLowerCase()
              .compareTo(cleanStationName(b.name).toLowerCase());
        case _StopSort.operator:
          return Operators.byId(a.operatorId)
              .shortName
              .compareTo(Operators.byId(b.operatorId).shortName);
        case _StopSort.distance:
          return (a.distanceMetres ?? double.infinity)
              .compareTo(b.distanceMetres ?? double.infinity);
      }
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleStops;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby stops'),
        actions: [
          PopupMenuButton<_StopSort>(
            tooltip: 'Sort stops',
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _StopSort.distance, child: Text('Nearest')),
              PopupMenuItem(value: _StopSort.name, child: Text('Name')),
              PopupMenuItem(value: _StopSort.operator, child: Text('Operator')),
            ],
            icon: const Icon(Icons.sort),
          ),
          IconButton(
            tooltip: _mapView ? 'List view' : 'Map view',
            icon: Icon(_mapView ? Icons.view_list_outlined : Icons.map_outlined),
            onPressed: () => setState(() => _mapView = !_mapView),
          ),
          IconButton(
            tooltip: 'Refresh location',
            icon: const Icon(Icons.my_location),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  _searchAndTypeFilters(),
                  _operatorFilters(),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: StatusBanner(
                        message: _notice!,
                        color: AppTheme.signalTeal,
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: StatusBanner(
                        message: _error!,
                        color: AppTheme.hibiscus,
                        icon: Icons.error_outline,
                      ),
                    ),
                  Expanded(
                    child: visible.isEmpty
                        ? _emptyState()
                        : (_mapView ? _map(visible) : _list(visible)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _searchAndTypeFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        children: [
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search nearby stops or operators',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: _search.clear,
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<_StopTypeFilter>(
            segments: const [
              ButtonSegment(value: _StopTypeFilter.all, label: Text('All')),
              ButtonSegment(
                value: _StopTypeFilter.rail,
                label: Text('Rail'),
                icon: Icon(Icons.train_outlined),
              ),
              ButtonSegment(
                value: _StopTypeFilter.bus,
                label: Text('Bus'),
                icon: Icon(Icons.directions_bus_outlined),
              ),
            ],
            selected: {_typeFilter},
            onSelectionChanged: (value) {
              setState(() => _typeFilter = value.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _operatorFilters() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          ActionChip(
            avatar: const Icon(Icons.social_distance, size: 18),
            label: Text(formatDistance(_radius)),
            onPressed: () {
              setState(() => _radius = _radius >= 5000 ? 800 : _radius * 2);
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.explore_off_outlined, size: 56, color: AppTheme.slate),
        const SizedBox(height: 16),
        Text(
          _search.text.trim().isNotEmpty
              ? 'No matching nearby stops'
              : 'No stops within ${formatDistance(_radius)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Try another search, widen the radius, clear filters, or download more operator feeds from Offline data.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.slate),
        ),
      ],
    );
  }

  Widget _list(List<GtfsStop> stops) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: stops.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => StopCard(
        stop: stops[i],
        onTap: () => _openStop(stops[i]),
      ),
    );
  }

  Widget _map(List<GtfsStop> stops) {
    final location = _location;
    if (location == null) return _emptyState();

    final centre = LatLng(location.lat, location.lon);
    return FlutterMap(
      options: MapOptions(initialCenter: centre, initialZoom: 14.5),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.xploremy',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: centre,
              width: 24,
              height: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.signalTeal,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
            for (final stop in stops)
              Marker(
                point: LatLng(stop.lat, stop.lon),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => _openStop(stop),
                  child: const Icon(
                    Icons.location_on,
                    color: AppTheme.hibiscus,
                    size: 34,
                  ),
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
