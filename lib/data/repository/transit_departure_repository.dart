part of '../transit_repository.dart';

extension TransitDepartureRepository on TransitRepository {
  DateTime _midnight(
    DateTime date,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  Future<List<Departure>> getDeparturesForStop({
    required String operatorId,
    required String stopId,
    int limit = 12,
    DateTime? after,
  }) async {
    final reference = after ?? DateTime.now();

    final actualNow = DateTime.now();

    final today = _midnight(reference);

    final yesterday = today.subtract(
      const Duration(days: 1),
    );

    final tomorrow = today.add(
      const Duration(days: 1),
    );

    final referenceSeconds =
        reference.hour * 3600 + reference.minute * 60 + reference.second;

    final candidates = <_ServiceDepartureRow>[];

    final previousRows = await _store.rawDepartures(
      operatorId: operatorId,
      stopId: stopId,
      serviceDate: yesterday,
      fromSeconds: referenceSeconds + 86400,
      limit: limit * 2,
    );

    for (final row in previousRows) {
      final scheduled = (row['departure_seconds'] as num).toInt();

      final scheduledAt = yesterday.add(
        Duration(
          seconds: scheduled,
        ),
      );

      if (!scheduledAt.isBefore(
        reference,
      )) {
        candidates.add(
          _ServiceDepartureRow(
            row: row,
            serviceDate: yesterday,
            scheduledAt: scheduledAt,
          ),
        );
      }
    }

    final todayRows = await _store.rawDepartures(
      operatorId: operatorId,
      stopId: stopId,
      serviceDate: today,
      fromSeconds: referenceSeconds,
      limit: limit * 4,
    );

    for (final row in todayRows) {
      final scheduled = (row['departure_seconds'] as num).toInt();

      final scheduledAt = today.add(
        Duration(
          seconds: scheduled,
        ),
      );

      if (!scheduledAt.isBefore(
        reference,
      )) {
        candidates.add(
          _ServiceDepartureRow(
            row: row,
            serviceDate: today,
            scheduledAt: scheduledAt,
          ),
        );
      }
    }

    if (candidates.length < limit) {
      final tomorrowRows = await _store.rawDepartures(
        operatorId: operatorId,
        stopId: stopId,
        serviceDate: tomorrow,
        fromSeconds: 0,
        limit: limit * 3,
      );

      for (final row in tomorrowRows) {
        final scheduled = (row['departure_seconds'] as num).toInt();

        final scheduledAt = tomorrow.add(
          Duration(
            seconds: scheduled,
          ),
        );

        candidates.add(
          _ServiceDepartureRow(
            row: row,
            serviceDate: tomorrow,
            scheduledAt: scheduledAt,
          ),
        );
      }
    }

    candidates.sort(
      (a, b) => a.scheduledAt.compareTo(
        b.scheduledAt,
      ),
    );

    final isNearNow = reference.difference(actualNow).inSeconds.abs() <= 300;

    final vehicles = isNearNow
        ? await _vehiclePositions(
            operatorId,
          )
        : const <VehiclePosition>[];

    final byTrip = <String, VehiclePosition>{};

    for (final vehicle in vehicles) {
      final tripId = vehicle.tripId;

      if (tripId != null) {
        byTrip[tripId] = vehicle;
      }
    }

    final result = <Departure>[];

    final seen = <String>{};

    for (final candidate in candidates) {
      final row = candidate.row;

      final scheduled = (row['departure_seconds'] as num).toInt();

      final tripId = row['trip_id'] as String;

      final routeId = (row['route_id'] as String?) ?? '';

      final shortName = (row['short_name'] as String?) ?? '';

      final longName = (row['long_name'] as String?) ?? '';

      final rawLabel = shortName.trim().isNotEmpty ? shortName : routeId;

      final routeLabel = _friendlyRouteLabel(
        rawLabel,
        longName,
      );

      final rawHeadsign = row['headsign'] as String?;

      final headsign = rawHeadsign != null && rawHeadsign.trim().isNotEmpty
          ? rawHeadsign.trim()
          : longName;

      final key = '$routeId|'
          '$headsign|'
          '${candidate.scheduledAt.millisecondsSinceEpoch}';

      if (!seen.add(key)) {
        continue;
      }

      int? liveDelay;

      final vehicle = byTrip[tripId];

      if (vehicle != null && isNearNow) {
        liveDelay = await _estimateDelaySeconds(
          operatorId: operatorId,
          tripId: tripId,
          vehicle: vehicle,
          serviceDate: candidate.serviceDate,
          now: actualNow,
        );
      }

      final secondsUntil =
          candidate.scheduledAt.difference(reference).inSeconds;

      if (secondsUntil < 0) {
        continue;
      }

      result.add(
        Departure(
          operatorId: operatorId,
          routeId: routeId,
          tripId: tripId,
          routeLabel: routeLabel,
          routeLongName: longName,
          headsign: headsign,
          scheduledSeconds: scheduled,
          scheduledAt: candidate.scheduledAt,
          secondsUntil: secondsUntil,
          routeType: (row['type'] as num?)?.toInt() ?? 3,
          liveDelaySeconds: liveDelay,
        ),
      );

      if (result.length >= limit) {
        break;
      }
    }

    return result;
  }

  String _friendlyRouteLabel(
    String raw,
    String longName,
  ) {
    final value = raw.trim();

    switch (value.toUpperCase()) {
      case 'MRL':
        return 'Monorail';

      case 'KJL':
        return 'Kelana Jaya';

      case 'AGL':
        return 'Ampang';

      case 'SPL':
        return 'Sri Petaling';

      case 'PYL':
        return 'Putrajaya';

      case 'KGL':
        return 'Kajang';

      default:
        if (value.isNotEmpty) {
          return value;
        }

        if (longName.trim().isNotEmpty) {
          return longName.trim();
        }

        return 'Transit';
    }
  }

  Future<int?> _estimateDelaySeconds({
    required String operatorId,
    required String tripId,
    required VehiclePosition vehicle,
    required DateTime serviceDate,
    required DateTime now,
  }) async {
    final shape = await _store.tripShape(
      operatorId,
      tripId,
    );

    if (shape.isEmpty) {
      return null;
    }

    GtfsStop? closest;

    var best = double.infinity;

    for (final stop in shape) {
      final distance = haversineMetres(
        vehicle.lat,
        vehicle.lon,
        stop.lat,
        stop.lon,
      );

      if (distance < best) {
        best = distance;
        closest = stop;
      }
    }

    if (closest == null || best > 2500) {
      return null;
    }

    final scheduledSeconds = await _store.scheduledTimeForTripAtStop(
      operatorId: operatorId,
      tripId: tripId,
      stopId: closest.stopId,
    );

    if (scheduledSeconds == null) {
      return null;
    }

    final scheduledAt = _midnight(serviceDate).add(
      Duration(
        seconds: scheduledSeconds,
      ),
    );

    final delay = now.difference(scheduledAt).inSeconds;

    if (delay.abs() > 7200) {
      return null;
    }

    return delay;
  }

  Future<List<VehiclePosition>> _vehiclePositions(
    String operatorId,
  ) async {
    final op = Operators.byId(
      operatorId,
    );

    if (!op.hasRealtime) {
      return const [];
    }

    final fetchedAt = _vehicleFetchedAt[operatorId];

    if (fetchedAt != null &&
        DateTime.now().difference(
              fetchedAt,
            ) <
            const Duration(
              seconds: 20,
            )) {
      return _vehicleCache[operatorId] ?? const [];
    }

    try {
      final vehicles = await _api.fetchVehiclePositions(
        op,
      );

      _vehicleCache[operatorId] = vehicles;

      _vehicleFetchedAt[operatorId] = DateTime.now();

      return vehicles;
    } catch (_) {
      return _vehicleCache[operatorId] ?? const [];
    }
  }

  Future<List<VehiclePosition>> liveVehicles(
    String operatorId,
  ) {
    return _vehiclePositions(
      operatorId,
    );
  }

  Future<List<GtfsStop>> tripShape(
    String operatorId,
    String tripId,
  ) {
    return _store.tripShape(
      operatorId,
      tripId,
    );
  }

  Future<ServiceActivityLevel> serviceActivityLevel(
    String operatorId,
    String stopId,
  ) async {
    final density = await _store.hourlyDensity(
      operatorId,
      stopId,
    );

    if (density.isEmpty) {
      return ServiceActivityLevel.low;
    }

    final peak = density.values.reduce(
      (a, b) => a > b ? a : b,
    );

    final current = density[DateTime.now().hour] ?? 0;

    if (peak == 0) {
      return ServiceActivityLevel.low;
    }

    final ratio = current / peak;

    if (ratio >= 0.75) {
      return ServiceActivityLevel.high;
    }

    if (ratio >= 0.4) {
      return ServiceActivityLevel.moderate;
    }

    return ServiceActivityLevel.low;
  }

  Future<List<String>> operatorsNear(
    double lat,
    double lon,
  ) async {
    final stops = await TransitStopRepository(this).getNearbyStops(
      lat: lat,
      lon: lon,
      radiusMetres: 2000,
    );

    return stops
        .map(
          (stop) => stop.operatorId,
        )
        .toSet()
        .toList();
  }
}

extension TransitEnhancedDepartureRepository on TransitRepository {
  DateTime? realtimeFetchedAt(String operatorId) =>
      _vehicleFetchedAt[operatorId];

  Future<ServiceSpan?> serviceSpanForStop({
    required String operatorId,
    required String stopId,
    DateTime? date,
  }) async {
    final target = date ?? DateTime.now();
    final day = DateTime(target.year, target.month, target.day);
    final span = await LocalGtfsServiceSpanStore(_store).serviceSpanForStop(
      operatorId: operatorId,
      stopId: stopId,
      serviceDate: day,
    );
    if (span == null) return null;
    return ServiceSpan(
      firstAt: day.add(Duration(seconds: span['first']!)),
      lastAt: day.add(Duration(seconds: span['last']!)),
    );
  }

  Future<List<VehiclePosition>> relevantVehicles({
    required String operatorId,
    String? tripId,
    String? routeId,
    GtfsStop? nearStop,
    double maxDistanceMetres = 7000,
  }) async {
    final vehicles =
        await TransitDepartureRepository(this).liveVehicles(operatorId);
    if (vehicles.isEmpty) return const [];

    final cleanTrip = tripId?.trim();
    if (cleanTrip != null && cleanTrip.isNotEmpty) {
      final exactTrip =
          vehicles.where((vehicle) => vehicle.tripId == cleanTrip).toList();
      if (exactTrip.isNotEmpty) return exactTrip;
    }

    final cleanRoute = routeId?.trim();
    if (cleanRoute != null && cleanRoute.isNotEmpty) {
      final sameRoute =
          vehicles.where((vehicle) => vehicle.routeId == cleanRoute).toList();
      if (sameRoute.isNotEmpty) {
        if (nearStop == null) return sameRoute;
        final nearbyRoute = sameRoute.where((vehicle) {
          return haversineMetres(
                  vehicle.lat, vehicle.lon, nearStop.lat, nearStop.lon) <=
              maxDistanceMetres;
        }).toList();
        return nearbyRoute.isNotEmpty
            ? nearbyRoute
            : sameRoute.take(20).toList();
      }
    }

    if (nearStop != null) {
      final nearby = vehicles.where((vehicle) {
        return haversineMetres(
                vehicle.lat, vehicle.lon, nearStop.lat, nearStop.lon) <=
            maxDistanceMetres;
      }).toList();
      if (nearby.isNotEmpty) return nearby;
      return const [];
    }

    return vehicles.take(20).toList();
  }

  Future<List<TripTimetableEntry>> tripTimetable({
    required String operatorId,
    required String tripId,
    required DateTime serviceDate,
    required String currentStopId,
    required int currentScheduledSeconds,
  }) async {
    final templateSeconds = await _store.scheduledTimeForTripAtStop(
      operatorId: operatorId,
      tripId: tripId,
      stopId: currentStopId,
    );
    final offsetSeconds =
        templateSeconds == null ? 0 : currentScheduledSeconds - templateSeconds;
    return _store.tripTimetable(
      operatorId: operatorId,
      tripId: tripId,
      serviceDate: serviceDate,
      offsetSeconds: offsetSeconds,
    );
  }
}
