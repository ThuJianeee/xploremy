import 'dart:async';

import '../core/config.dart';
import 'gtfs_api.dart';
import 'local_store.dart';
import 'models.dart';

/// Single façade used by the UI for static schedules, offline cache and
/// GTFS-realtime vehicle positions.
class TransitRepository {
  TransitRepository({GtfsApi? api, LocalGtfsStore? store})
      : _api = api ?? GtfsApi(),
        _store = store ?? LocalGtfsStore();

  final GtfsApi _api;
  final LocalGtfsStore _store;

  final Map<String, List<VehiclePosition>> _vehicleCache = {};
  final Map<String, DateTime> _vehicleFetchedAt = {};

  LocalGtfsStore get store => _store;

  Future<DateTime?> lastSync(String operatorId) => _store.lastSync(operatorId);

  Future<List<String>> syncedOperatorIds() => _store.cachedOperatorIds();

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
        results.add(
          SyncResult(operator: op, skipped: false, stops: 0, error: '$e'),
        );
      }
    }
    return results;
  }

  Future<void> clearCache() => _store.clear();

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

  /// Correct upcoming departures using calendar.txt, calendar_dates.txt and
  /// frequencies.txt. GTFS times >= 24:00 are converted to their actual local
  /// DateTime so next-day service is displayed honestly.
  Future<List<Departure>> getDeparturesForStop({
    required String operatorId,
    required String stopId,
    int limit = 12,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nowSeconds = now.hour * 3600 + now.minute * 60 + now.second;

    final collected = <_ServiceDeparture>[];

    Future<void> collectFor(
      DateTime serviceDate,
      int fromSeconds, {
      int queryLimit = 36,
    }) async {
      final rows = await _store.rawDepartures(
        operatorId: operatorId,
        stopId: stopId,
        serviceDate: serviceDate,
        fromSeconds: fromSeconds,
        limit: queryLimit,
      );
      for (final row in rows) {
        final scheduled = (row['departure_seconds'] as num).toInt();
        final scheduledAt = serviceDate.add(Duration(seconds: scheduled));
        if (scheduledAt.isBefore(now)) continue;
        collected.add(_ServiceDeparture(row: row, scheduledAt: scheduledAt));
      }
    }

    // Catch trips belonging to yesterday's service day that use 24:xx/25:xx.
    await collectFor(
      today.subtract(const Duration(days: 1)),
      nowSeconds + 86400,
      queryLimit: limit * 2,
    );
    await collectFor(today, nowSeconds, queryLimit: limit * 3);

    // Only when today's service is finished, show the next service day. The UI
    // labels it as Tomorrow instead of silently wrapping 06:00 by +24 hours.
    if (collected.isEmpty) {
      await collectFor(
        today.add(const Duration(days: 1)),
        0,
        queryLimit: limit,
      );
    }

    collected.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final departures = <Departure>[];
    final seen = <String>{};
    for (final item in collected) {
      final row = item.row;
      final routeId = (row['route_id'] as String?) ?? '';
      final rawHeadsign = (row['headsign'] as String?) ?? '';
      final key = '$routeId|$rawHeadsign|${item.scheduledAt.millisecondsSinceEpoch}';
      if (!seen.add(key)) continue;

      final shortName = (row['short_name'] as String?) ?? '';
      final longName = (row['long_name'] as String?) ?? '';
      final secondsUntil = item.scheduledAt.difference(now).inSeconds;

      departures.add(
        Departure(
          operatorId: operatorId,
          tripId: row['trip_id'] as String,
          routeLabel: _friendlyRouteLabel(shortName, routeId),
          routeLongName: longName,
          headsign: _friendlyHeadsign(rawHeadsign, longName),
          scheduledSeconds: (row['departure_seconds'] as num).toInt(),
          scheduledAt: item.scheduledAt,
          secondsUntil: secondsUntil < 0 ? 0 : secondsUntil,
          routeType: (row['type'] as num?)?.toInt() ?? 3,
          // The official API currently publishes vehicle positions only, not
          // GTFS-RT TripUpdates. We therefore do not fabricate a live ETA.
          liveDelaySeconds: null,
        ),
      );
      if (departures.length >= limit) break;
    }
    return departures;
  }

  String _friendlyRouteLabel(String shortName, String routeId) {
    final label = shortName.trim().isNotEmpty ? shortName.trim() : routeId.trim();
    return switch (label.toUpperCase()) {
      'MRL' => 'Monorail',
      'KJL' => 'Kelana Jaya',
      'AGL' => 'Ampang',
      'SPL' => 'Sri Petaling',
      'KGL' => 'Kajang',
      'PYL' => 'Putrajaya',
      _ => label.isEmpty ? '—' : label,
    };
  }

  String _friendlyHeadsign(String headsign, String longName) {
    final value = headsign.trim();
    if (value.isEmpty) {
      return longName.trim().isEmpty ? 'Destination' : longName.trim();
    }

    final lower = value.toLowerCase();
    final toIndex = lower.lastIndexOf(' to ');
    if (lower.startsWith('from ') && toIndex > 5 && toIndex + 4 < value.length) {
      return 'Towards ${value.substring(toIndex + 4).trim()}';
    }
    return value;
  }

  /// Live vehicles are cached for 20 seconds. data.gov.my states that vehicle
  /// position feeds refresh every 30 seconds.
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
      final cachedAt = _vehicleFetchedAt[operatorId];
      if (cachedAt != null &&
          DateTime.now().difference(cachedAt) < const Duration(minutes: 2)) {
        return _vehicleCache[operatorId] ?? const [];
      }
      return const [];
    }
  }

  Future<List<VehiclePosition>> liveVehicles(String operatorId) =>
      _vehiclePositions(operatorId);

  Future<List<GtfsStop>> tripShape(String operatorId, String tripId) =>
      _store.tripShape(operatorId, tripId);

  /// Kept for compatibility with the existing UI. This is a schedule-density
  /// heuristic, not measured passenger crowding.
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

  Future<List<String>> operatorsNear(double lat, double lon) async {
    final stops = await getNearbyStops(lat: lat, lon: lon, radiusMetres: 2000);
    return stops.map((s) => s.operatorId).toSet().toList();
  }
}

class _ServiceDeparture {
  const _ServiceDeparture({required this.row, required this.scheduledAt});

  final Map<String, Object?> row;
  final DateTime scheduledAt;
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
