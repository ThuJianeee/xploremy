import 'dart:async';

import '../core/config.dart';
import '../core/geo.dart';
import 'gtfs_api.dart';
import 'local_store.dart';
import 'mock_feed.dart';
import 'models.dart';

/// MODULE 1 (public surface) — the single façade the UI talks to.
///
/// `getNearbyStops()` and `getDeparturesForStop()` are the two functions the
/// rest of the team codes against; they read from the SQLite cache, so they
/// keep working offline once a feed has been synced at least once.
class TransitRepository {
  TransitRepository({GtfsApi? api, LocalGtfsStore? store})
      : _api = api ?? GtfsApi(),
        _store = store ?? LocalGtfsStore();

  final GtfsApi _api;
  final LocalGtfsStore _store;

  final Map<String, List<VehiclePosition>> _vehicleCache = {};
  final Map<String, DateTime> _vehicleFetchedAt = {};

  LocalGtfsStore get store => _store;

  // ------------------------------------------------------------------ sync

  Future<DateTime?> lastSync(String operatorId) => _store.lastSync(operatorId);

  Future<List<String>> syncedOperatorIds() => _store.cachedOperatorIds();

  /// Downloads + caches one operator's static feed.
  Future<SyncResult> syncOperator(Operator op, {bool force = false}) async {
    final last = await _store.lastSync(op.id);
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < AppConfig.staticFeedTtl) {
      return SyncResult(operator: op, skipped: true, stops: 0);
    }
    final feed = await _api.fetchStaticFeed(op);
    if (feed.isEmpty) {
      throw GtfsException('${op.shortName} returned an empty feed.');
    }
    await _store.saveFeed(feed);
    return SyncResult(operator: op, skipped: false, stops: feed.stops.length);
  }

  /// Syncs several operators, collecting per-operator failures instead of
  /// aborting the whole run (BAS.MY feeds are occasionally unavailable).
  Future<List<SyncResult>> syncAll(
    List<Operator> operators, {
    bool force = false,
    void Function(Operator op)? onProgress,
  }) async {
    final results = <SyncResult>[];
    for (final op in operators) {
      onProgress?.call(op);
      try {
        results.add(await syncOperator(op, force: force));
      } catch (e) {
        results.add(SyncResult(operator: op, skipped: false, stops: 0, error: '$e'));
      }
    }
    return results;
  }

  /// Loads a small built-in demo feed so the UI is usable with no network
  /// (also what the team built against before the live feeds were wired up).
  Future<void> loadMockFeed() async {
    for (final feed in buildMockFeeds()) {
      await _store.saveFeed(feed);
    }
  }

  Future<void> clearCache() => _store.clear();

  // --------------------------------------------------------------- queries

  /// MODULE 2 — stops around a coordinate, nearest first.
  Future<List<GtfsStop>> getNearbyStops({
    required double lat,
    required double lon,
    double radiusMetres = AppConfig.nearbyRadiusMetres,
    List<String>? operatorIds,
    int limit = 40,
  }) {
    return _store.nearbyStops(
      lat: lat,
      lon: lon,
      radiusMetres: radiusMetres,
      operatorIds: operatorIds,
      limit: limit,
    );
  }

  Future<List<GtfsStop>> searchStops(String query) =>
      _store.searchStops(query);

  Future<GtfsStop?> getStop(String operatorId, String stopId) =>
      _store.stopById(operatorId, stopId);

  /// MODULE 3 — upcoming departures, enriched with the live reliability layer.
  Future<List<Departure>> getDeparturesForStop({
    required String operatorId,
    required String stopId,
    int limit = 12,
  }) async {
    final now = nowSecondsOfDay();
    var rows = await _store.rawDepartures(
      operatorId: operatorId,
      stopId: stopId,
      fromSeconds: now,
      limit: limit,
    );

    // Late at night wrap around to the start of the service day.
    if (rows.isEmpty) {
      rows = await _store.rawDepartures(
        operatorId: operatorId,
        stopId: stopId,
        fromSeconds: 0,
        limit: limit,
      );
    }

    final vehicles = await _vehiclePositions(operatorId);
    final byTrip = {
      for (final v in vehicles)
        if (v.tripId != null) v.tripId!: v,
    };

    final stop = await _store.stopById(operatorId, stopId);

    final departures = <Departure>[];
    for (final row in rows) {
      final scheduled = (row['departure_seconds'] as num).toInt();
      var untilSeconds = scheduled - now;
      if (untilSeconds < 0) untilSeconds += 86400;

      final tripId = row['trip_id'] as String;
      int? delay;
      final vehicle = byTrip[tripId];
      if (vehicle != null && stop != null) {
        delay = await _estimateDelaySeconds(
          operatorId: operatorId,
          tripId: tripId,
          vehicle: vehicle,
          scheduledSeconds: scheduled,
          nowSeconds: now,
        );
      }

      departures.add(Departure(
        operatorId: operatorId,
        tripId: tripId,
        routeLabel: ((row['short_name'] as String?)?.isNotEmpty ?? false)
            ? row['short_name'] as String
            : (row['route_id'] as String? ?? '—'),
        routeLongName: (row['long_name'] as String?) ?? '',
        headsign: ((row['headsign'] as String?)?.isNotEmpty ?? false)
            ? row['headsign'] as String
            : (row['long_name'] as String? ?? 'Destination'),
        scheduledSeconds: scheduled,
        secondsUntil: untilSeconds,
        routeType: (row['type'] as num?)?.toInt() ?? 3,
        liveDelaySeconds: delay,
      ));
    }
    return departures;
  }

  /// Reliability layer: where *should* the vehicle be right now versus where
  /// its GPS says it is. We find the scheduled stop closest to the live
  /// position and compare that stop's scheduled time against the clock.
  Future<int?> _estimateDelaySeconds({
    required String operatorId,
    required String tripId,
    required VehiclePosition vehicle,
    required int scheduledSeconds,
    required int nowSeconds,
  }) async {
    final shape = await _store.tripShape(operatorId, tripId);
    if (shape.isEmpty) return null;

    GtfsStop? closest;
    var best = double.infinity;
    for (final s in shape) {
      final d = haversineMetres(vehicle.lat, vehicle.lon, s.lat, s.lon);
      if (d < best) {
        best = d;
        closest = s;
      }
    }
    if (closest == null || best > 2500) return null;

    final rows = await _store.rawDepartures(
      operatorId: operatorId,
      stopId: closest.stopId,
      fromSeconds: 0,
      limit: 400,
    );
    final match = rows.where((r) => r['trip_id'] == tripId).toList();
    if (match.isEmpty) return null;

    final scheduledAtClosest =
        (match.first['departure_seconds'] as num).toInt();
    return nowSeconds - scheduledAtClosest;
  }

  /// Live vehicles for an operator, cached for 20 seconds.
  Future<List<VehiclePosition>> _vehiclePositions(String operatorId) async {
    final op = Operators.byId(operatorId);
    if (!op.hasRealtime) return const [];

    final fetchedAt = _vehicleFetchedAt[operatorId];
    if (fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < const Duration(seconds: 20)) {
      return _vehicleCache[operatorId] ?? const [];
    }
    try {
      final vehicles = await _api.fetchVehiclePositions(op);
      _vehicleCache[operatorId] = vehicles;
      _vehicleFetchedAt[operatorId] = DateTime.now();
      return vehicles;
    } catch (_) {
      return _vehicleCache[operatorId] ?? const [];
    }
  }

  Future<List<VehiclePosition>> liveVehicles(String operatorId) =>
      _vehiclePositions(operatorId);

  Future<List<GtfsStop>> tripShape(String operatorId, String tripId) =>
      _store.tripShape(operatorId, tripId);

  /// "Usually crowded" heuristic: departures in the current hour compared to
  /// the busiest hour of the day at this stop.
  Future<CrowdLevel> crowdLevel(String operatorId, String stopId) async {
    final density = await _store.hourlyDensity(operatorId, stopId);
    if (density.isEmpty) return CrowdLevel.quiet;
    final peak = density.values.reduce((a, b) => a > b ? a : b);
    final current = density[DateTime.now().hour] ?? 0;
    if (peak == 0) return CrowdLevel.quiet;
    final ratio = current / peak;
    if (ratio >= 0.75) return CrowdLevel.busy;
    if (ratio >= 0.4) return CrowdLevel.moderate;
    return CrowdLevel.quiet;
  }

  /// Very simple multi-modal hint: which operators serve stops near a point.
  Future<List<String>> operatorsNear(double lat, double lon) async {
    final stops = await getNearbyStops(lat: lat, lon: lon, radiusMetres: 2000);
    return stops.map((s) => s.operatorId).toSet().toList();
  }
}

class SyncResult {
  const SyncResult({
    required this.operator,
    required this.skipped,
    required this.stops,
    this.error,
  });

  final Operator operator;
  final bool skipped;
  final int stops;
  final String? error;

  bool get ok => error == null;
}
