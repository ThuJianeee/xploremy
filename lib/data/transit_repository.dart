import '../core/config.dart';
import '../core/geo.dart';
import 'gtfs_api.dart';
import 'local_store.dart';
import 'mock_feed.dart';
import 'models.dart';

/// Main transport data facade.
///
/// Handles:
/// - official GTFS static data
/// - SQLite offline cache
/// - nearby stops
/// - scheduled departures
/// - realtime vehicle positions
/// - crowd heuristic
/// - direct route planning
/// - one-transfer / multi-modal route planning
class TransitRepository {
  TransitRepository({
    GtfsApi? api,
    LocalGtfsStore? store,
  })  : _api = api ?? GtfsApi(),
        _store = store ?? LocalGtfsStore();

  final GtfsApi _api;
  final LocalGtfsStore _store;

  final Map<String, List<VehiclePosition>> _vehicleCache = {};

  final Map<String, DateTime> _vehicleFetchedAt = {};

  LocalGtfsStore get store => _store;

  // ==============================================================
  // SYNC
  // ==============================================================

  Future<DateTime?> lastSync(
    String operatorId,
  ) {
    return _store.lastSync(
      operatorId,
    );
  }

  Future<List<String>> syncedOperatorIds() {
    return _store.cachedOperatorIds();
  }

  Future<SyncResult> syncOperator(
    Operator op, {
    bool force = false,
  }) async {
    final last = await _store.lastSync(
      op.id,
    );

    if (!force &&
        last != null &&
        DateTime.now().difference(last) < AppConfig.staticFeedTtl) {
      return SyncResult(
        operator: op,
        skipped: true,
        stops: 0,
      );
    }

    final feed = await _api.fetchStaticFeed(
      op,
    );

    if (feed.isEmpty) {
      throw GtfsException(
        '${op.shortName} returned an empty feed.',
      );
    }

    await _store.saveFeed(feed);

    return SyncResult(
      operator: op,
      skipped: false,
      stops: feed.stops.length,
    );
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
        results.add(
          await syncOperator(
            op,
            force: force,
          ),
        );
      } catch (e) {
        results.add(
          SyncResult(
            operator: op,
            skipped: false,
            stops: 0,
            error: '$e',
          ),
        );
      }
    }

    return results;
  }

  Future<void> loadMockFeed() async {
    for (final feed in buildMockFeeds()) {
      await _store.saveFeed(feed);
    }
  }

  Future<void> clearCache() {
    return _store.clear();
  }

  // ==============================================================
  // STOPS
  // ==============================================================

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

  Future<List<GtfsStop>> searchStops(
    String query,
  ) {
    return _store.searchStops(query);
  }

  Future<List<PlannerStopOption>> searchPlannerStops(
    String query,
  ) {
    return _store.searchPlannerStops(
      query,
    );
  }

  Future<List<PlannerStopOption>> plannerOptionsForStop({
    required String operatorId,
    required String stopId,
  }) {
    return _store.plannerOptionsForStop(
      operatorId: operatorId,
      stopId: stopId,
    );
  }

  Future<GtfsStop?> getStop(
    String operatorId,
    String stopId,
  ) {
    return _store.stopById(
      operatorId,
      stopId,
    );
  }

  DateTime _midnight(
    DateTime date,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  // ==============================================================
  // DEPARTURES
  // ==============================================================

  Future<List<Departure>> getDeparturesForStop({
    required String operatorId,
    required String stopId,
    int limit = 12,

    /// Route planner can ask for departures after a future transfer time.
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

    // ------------------------------------------------------------
    // Previous GTFS service day.
    //
    // Needed for GTFS values such as 24:30 or 25:10.
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // Current service day
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // Tomorrow
    // ------------------------------------------------------------

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

    /// Realtime matching only makes sense if this query is approximately now.
    ///
    /// It should not attempt to use a current vehicle location when calculating
    /// a future second leg after a transfer.
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

  // ==============================================================
  // REALTIME / RELIABILITY
  // ==============================================================

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

    /// Avoid showing unrealistic delay calculations if the live vehicle cannot
    /// be safely matched to the current timetable.
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

  // ==============================================================
  // CROWDING
  // ==============================================================

  Future<CrowdLevel> crowdLevel(
    String operatorId,
    String stopId,
  ) async {
    final density = await _store.hourlyDensity(
      operatorId,
      stopId,
    );

    if (density.isEmpty) {
      return CrowdLevel.quiet;
    }

    final peak = density.values.reduce(
      (a, b) => a > b ? a : b,
    );

    final current = density[DateTime.now().hour] ?? 0;

    if (peak == 0) {
      return CrowdLevel.quiet;
    }

    final ratio = current / peak;

    if (ratio >= 0.75) {
      return CrowdLevel.busy;
    }

    if (ratio >= 0.4) {
      return CrowdLevel.moderate;
    }

    return CrowdLevel.quiet;
  }

  Future<List<String>> operatorsNear(
    double lat,
    double lon,
  ) async {
    final stops = await getNearbyStops(
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

  // ==============================================================
  // JOURNEY PLANNER - PUBLIC ENTRY
  // ==============================================================

  /// First tries a direct route.
  ///
  /// If there is no direct journey, attempts one transfer / multi-modal route.
  Future<List<JourneyPlan>> planJourneys({
    required PlannerStopOption from,
    required PlannerStopOption to,
    int limit = 5,
  }) async {
    final direct = await planDirectJourneys(
      from: from,
      to: to,
      limit: limit,
    );

    if (direct.isNotEmpty) {
      return direct;
    }

    return _planOneTransferJourneys(
      from: from,
      to: to,
      limit: limit,
    );
  }

  // ==============================================================
  // DIRECT JOURNEY
  // ==============================================================

  Future<List<JourneyPlan>> planDirectJourneys({
    required PlannerStopOption from,
    required PlannerStopOption to,
    int limit = 5,
    DateTime? earliestDeparture,
  }) async {
    final legs = await _directLegs(
      from: from,
      to: to,
      earliestDeparture: earliestDeparture ?? DateTime.now(),
      limit: limit,
    );

    return [
      for (final leg in legs)
        JourneyPlan(
          legs: [
            leg,
          ],
        ),
    ];
  }

  Future<List<JourneyLeg>> _directLegs({
    required PlannerStopOption from,
    required PlannerStopOption to,
    required DateTime earliestDeparture,
    int limit = 5,
  }) async {
    if (from.operatorId != to.operatorId) {
      return const [];
    }

    if (from.routeId != to.routeId) {
      return const [];
    }

    final legs = <JourneyLeg>[];

    final seen = <String>{};

    for (final fromStop in from.stops) {
      final departures = await getDeparturesForStop(
        operatorId: fromStop.operatorId,
        stopId: fromStop.stopId,
        limit: 120,
        after: earliestDeparture,
      );

      for (final departure in departures) {
        if (departure.routeId != from.routeId) {
          continue;
        }

        for (final toStop in to.stops) {
          if (fromStop.operatorId == toStop.operatorId &&
              fromStop.stopId == toStop.stopId) {
            continue;
          }

          final window = await _store.tripStopWindow(
            operatorId: from.operatorId,
            tripId: departure.tripId,
            fromStopId: fromStop.stopId,
            toStopId: toStop.stopId,
          );

          if (window == null) {
            continue;
          }

          final fromSeconds = window['from_seconds'];

          final toSeconds = window['to_seconds'];

          final fromSequence = window['from_sequence'];

          final toSequence = window['to_sequence'];

          if (fromSeconds == null ||
              toSeconds == null ||
              fromSequence == null ||
              toSequence == null) {
            continue;
          }

          final travelSeconds = toSeconds - fromSeconds;

          if (travelSeconds <= 0) {
            continue;
          }

          final arrivalAt = departure.scheduledAt.add(
            Duration(
              seconds: travelSeconds,
            ),
          );

          final key = '${departure.routeId}|'
              '${departure.scheduledAt.millisecondsSinceEpoch}|'
              '${fromStop.stopId}|'
              '${toStop.stopId}';

          if (!seen.add(key)) {
            continue;
          }

          legs.add(
            JourneyLeg(
              fromStop: fromStop,
              toStop: toStop,
              operatorId: departure.operatorId,
              routeId: departure.routeId,
              routeLabel: departure.routeLabel,
              routeLongName: departure.routeLongName,
              headsign: departure.headsign,
              departureAt: departure.scheduledAt,
              arrivalAt: arrivalAt,
              stopCount: toSequence - fromSequence,
              routeType: departure.routeType,
            ),
          );
        }
      }
    }

    legs.sort(
      (a, b) => a.departureAt.compareTo(
        b.departureAt,
      ),
    );

    final unique = <String>{};

    final result = <JourneyLeg>[];

    for (final leg in legs) {
      final key = '${leg.routeId}|'
          '${leg.departureAt.millisecondsSinceEpoch}|'
          '${leg.toStop.stopId}';

      if (!unique.add(key)) {
        continue;
      }

      result.add(leg);

      if (result.length >= limit) {
        break;
      }
    }

    return result;
  }

  // ==============================================================
  // ONE TRANSFER / MULTI-MODAL
  // ==============================================================

  Future<List<JourneyPlan>> _planOneTransferJourneys({
    required PlannerStopOption from,
    required PlannerStopOption to,
    int limit = 5,
  }) async {
    /// If same exact route has no direct trip, don't artificially send the user
    /// through another line.
    if (from.operatorId == to.operatorId && from.routeId == to.routeId) {
      return const [];
    }

    final fromRouteStops = await _store.routeStops(
      operatorId: from.operatorId,
      routeId: from.routeId,
    );

    final toRouteStops = await _store.routeStops(
      operatorId: to.operatorId,
      routeId: to.routeId,
    );

    if (fromRouteStops.isEmpty || toRouteStops.isEmpty) {
      return const [];
    }

    final transferCandidates = <_TransferCandidate>[];

    /// Compare stops served by line A and line B.
    ///
    /// Nearby stops become possible interchange points.
    for (final firstStop in fromRouteStops) {
      for (final secondStop in toRouteStops) {
        final distance = haversineMetres(
          firstStop.lat,
          firstStop.lon,
          secondStop.lat,
          secondStop.lon,
        );

        final sameStationName = _stationKey(
              firstStop.name,
            ) ==
            _stationKey(
              secondStop.name,
            );

        /// Same-name interchanges can be slightly farther apart because
        /// platforms / entrances may have different coordinates.
        ///
        /// Different station names must be much closer to count as a sensible
        /// walking interchange.
        final allowedDistance = sameStationName ? 650.0 : 350.0;

        if (distance > allowedDistance) {
          continue;
        }

        transferCandidates.add(
          _TransferCandidate(
            firstStop: firstStop,
            secondStop: secondStop,
            distanceMetres: distance,
            sameStationName: sameStationName,
          ),
        );
      }
    }

    transferCandidates.sort(
      (a, b) {
        if (a.sameStationName != b.sameStationName) {
          return a.sameStationName ? -1 : 1;
        }

        return a.distanceMetres.compareTo(
          b.distanceMetres,
        );
      },
    );

    final searchStart = DateTime.now();

    final plans = <JourneyPlan>[];

    final usedTransferPairs = <String>{};

    /// Try the most likely interchange points first.
    for (final candidate in transferCandidates.take(20)) {
      final pairKey = '${candidate.firstStop.stopId}|'
          '${candidate.secondStop.stopId}';

      if (!usedTransferPairs.add(
        pairKey,
      )) {
        continue;
      }

      final walkSeconds = _transferWalkSeconds(
        candidate.distanceMetres,
      );

      final transfer = JourneyTransfer(
        fromStop: candidate.firstStop,
        toStop: candidate.secondStop,
        distanceMetres: candidate.distanceMetres,
        walkSeconds: walkSeconds,
      );

      final transferAtOrigin = _optionContainsStop(
        from,
        candidate.firstStop,
      );

      final transferAtDestination = _optionContainsStop(
        to,
        candidate.secondStop,
      );

      // ==========================================================
      // CASE 1
      //
      // Change line before boarding.
      //
      // Example:
      //
      // Selected:
      // KL Sentral - Monorail
      //
      // Destination:
      // KLCC - Kelana Jaya
      //
      // Result:
      // walk/change at KL Sentral
      // then take Kelana Jaya Line to KLCC.
      // ==========================================================

      if (transferAtOrigin && !transferAtDestination) {
        final secondStart = _singleStopOption(
          to,
          candidate.secondStop,
        );

        final secondLegs = await _directLegs(
          from: secondStart,
          to: to,
          earliestDeparture: searchStart.add(
            Duration(
              seconds: walkSeconds,
            ),
          ),
          limit: 3,
        );

        for (final leg in secondLegs) {
          plans.add(
            JourneyPlan(
              legs: [
                leg,
              ],
              beforeFirstLeg: transfer,
            ),
          );
        }

        continue;
      }

      // ==========================================================
      // CASE 2
      //
      // Ride first line and then walk/change at destination.
      // ==========================================================

      if (!transferAtOrigin && transferAtDestination) {
        final firstDestination = _singleStopOption(
          from,
          candidate.firstStop,
        );

        final firstLegs = await _directLegs(
          from: from,
          to: firstDestination,
          earliestDeparture: searchStart,
          limit: 3,
        );

        for (final leg in firstLegs) {
          plans.add(
            JourneyPlan(
              legs: [
                leg,
              ],
              afterLastLeg: transfer,
            ),
          );
        }

        continue;
      }

      /// Both points already represent the selected origin/destination area.
      ///
      /// No public transport ride would actually be needed.
      if (transferAtOrigin && transferAtDestination) {
        continue;
      }

      // ==========================================================
      // CASE 3
      //
      // Standard one-transfer journey.
      //
      // Route A:
      // Origin -> Interchange A
      //
      // Walk/change platform
      //
      // Route B:
      // Interchange B -> Destination
      // ==========================================================

      final firstDestination = _singleStopOption(
        from,
        candidate.firstStop,
      );

      final secondStart = _singleStopOption(
        to,
        candidate.secondStop,
      );

      final firstLegs = await _directLegs(
        from: from,
        to: firstDestination,
        earliestDeparture: searchStart,
        limit: 3,
      );

      for (final firstLeg in firstLegs) {
        final earliestSecondDeparture = firstLeg.arrivalAt.add(
          Duration(
            seconds: walkSeconds,
          ),
        );

        final secondLegs = await _directLegs(
          from: secondStart,
          to: to,
          earliestDeparture: earliestSecondDeparture,
          limit: 3,
        );

        for (final secondLeg in secondLegs) {
          plans.add(
            JourneyPlan(
              legs: [
                firstLeg,
                secondLeg,
              ],
              betweenLegs: transfer,
            ),
          );
        }
      }
    }

    /// Fastest arrival first.
    plans.sort(
      (a, b) {
        final arrivalCompare = a.journeyEndAt.compareTo(
          b.journeyEndAt,
        );

        if (arrivalCompare != 0) {
          return arrivalCompare;
        }

        return a.duration.compareTo(
          b.duration,
        );
      },
    );

    final unique = <String>{};

    final result = <JourneyPlan>[];

    for (final plan in plans) {
      final routeChain = plan.legs
          .map(
            (leg) => leg.routeId,
          )
          .join('>');

      final transferKey = plan.betweenLegs?.fromStop.stopId ??
          plan.beforeFirstLeg?.fromStop.stopId ??
          plan.afterLastLeg?.fromStop.stopId ??
          '';

      final key = '$routeChain|'
          '$transferKey|'
          '${plan.departureAt.millisecondsSinceEpoch}';

      if (!unique.add(key)) {
        continue;
      }

      result.add(plan);

      if (result.length >= limit) {
        break;
      }
    }

    return result;
  }

  // ==============================================================
  // JOURNEY PLANNER HELPERS
  // ==============================================================

  PlannerStopOption _singleStopOption(
    PlannerStopOption template,
    GtfsStop stop,
  ) {
    return PlannerStopOption(
      displayName: _cleanPlannerStopName(
        stop.name,
      ),
      operatorId: template.operatorId,
      routeId: template.routeId,
      routeShortName: template.routeShortName,
      routeLongName: template.routeLongName,
      routeType: template.routeType,
      stops: [
        stop,
      ],
    );
  }

  bool _optionContainsStop(
    PlannerStopOption option,
    GtfsStop candidate,
  ) {
    for (final stop in option.stops) {
      /// Exact GTFS stop ID.
      if (stop.operatorId == candidate.operatorId &&
          stop.stopId == candidate.stopId) {
        return true;
      }

      final sameName = _stationKey(stop.name) ==
          _stationKey(
            candidate.name,
          );

      if (!sameName) {
        continue;
      }

      final distance = haversineMetres(
        stop.lat,
        stop.lon,
        candidate.lat,
        candidate.lon,
      );

      /// Treat very-close same-name stop records as the same station/platform
      /// group.
      if (distance <= 120) {
        return true;
      }
    }

    return false;
  }

  String _stationKey(
    String value,
  ) {
    var result = value.toUpperCase().trim();

    result = result.replaceAll(
      RegExp(
        r'\s*-\s*REDONE\s*$',
        caseSensitive: false,
      ),
      '',
    );

    result = result.replaceAll(
      RegExp(
        r'[^A-Z0-9]+',
      ),
      ' ',
    );

    return result.trim();
  }

  String _cleanPlannerStopName(
    String value,
  ) {
    return value
        .replaceAll(
          RegExp(
            r'\s*-\s*REDONE\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  int _transferWalkSeconds(
    double distanceMetres,
  ) {
    /// Approximate walking speed:
    ///
    /// 1.25 metres / second
    ///
    /// Add another 90 seconds for stairs, concourse movement, platform change,
    /// traffic crossing, etc.
    final walkingSeconds = (distanceMetres / 1.25).ceil();

    final total = walkingSeconds + 90;

    /// Always allow at least 3 minutes for an interchange.
    return total < 180 ? 180 : total;
  }
}

class _TransferCandidate {
  const _TransferCandidate({
    required this.firstStop,
    required this.secondStop,
    required this.distanceMetres,
    required this.sameStationName,
  });

  final GtfsStop firstStop;
  final GtfsStop secondStop;

  final double distanceMetres;
  final bool sameStationName;
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

class _ServiceDepartureRow {
  const _ServiceDepartureRow({
    required this.row,
    required this.serviceDate,
    required this.scheduledAt,
  });

  final Map<String, Object?> row;
  final DateTime serviceDate;
  final DateTime scheduledAt;
}
