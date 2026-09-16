part of '../transit_repository.dart';

extension TransitDirectPlanner on TransitRepository {
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

    final transfer =
        await TransitTransferPlanner(this)._planOneTransferJourneys(
      from: from,
      to: to,
      limit: limit,
    );

    if (transfer.isNotEmpty) {
      return transfer;
    }

    return _planUsingAlternateStationRoutes(
      from: from,
      to: to,
      limit: limit,
    );
  }

  Future<List<JourneyPlan>> _planUsingAlternateStationRoutes({
    required PlannerStopOption from,
    required PlannerStopOption to,
    required int limit,
  }) async {
    final fromOptions = await _routeAlternativesForStation(from);
    final toOptions = await _routeAlternativesForStation(to);

    if (fromOptions.length == 1 && toOptions.length == 1) {
      return const [];
    }

    final plans = <JourneyPlan>[];

    for (final fromOption in fromOptions.take(8)) {
      for (final toOption in toOptions.take(8)) {
        final isOriginalPair = fromOption.operatorId == from.operatorId &&
            fromOption.routeId == from.routeId &&
            toOption.operatorId == to.operatorId &&
            toOption.routeId == to.routeId;

        if (isOriginalPair) continue;

        final direct = await planDirectJourneys(
          from: fromOption,
          to: toOption,
          limit: limit,
        );

        if (direct.isNotEmpty) {
          plans.addAll(direct);
          continue;
        }

        final transfer =
            await TransitTransferPlanner(this)._planOneTransferJourneys(
          from: fromOption,
          to: toOption,
          limit: limit,
        );
        plans.addAll(transfer);

        if (plans.length >= limit * 3) break;
      }
      if (plans.length >= limit * 3) break;
    }

    plans.sort((a, b) {
      final end = a.journeyEndAt.compareTo(b.journeyEndAt);
      if (end != 0) return end;
      return a.duration.compareTo(b.duration);
    });

    final seen = <String>{};
    final result = <JourneyPlan>[];

    for (final plan in plans) {
      final key = [
        for (final leg in plan.legs)
          '${leg.operatorId}:${leg.routeId}:${leg.tripId}',
        plan.beforeFirstLeg?.fromStop.stopId ?? '',
        plan.betweenLegs?.fromStop.stopId ?? '',
        plan.afterLastLeg?.fromStop.stopId ?? '',
        plan.departureAt.millisecondsSinceEpoch.toString(),
      ].join('|');

      if (!seen.add(key)) continue;
      result.add(plan);
      if (result.length >= limit) break;
    }

    return result;
  }

  Future<List<PlannerStopOption>> _routeAlternativesForStation(
    PlannerStopOption selected,
  ) async {
    final search = await _store.searchPlannerStops(
      cleanStationName(selected.displayName),
      limit: 60,
    );

    final selectedKey = _plannerStationKey(selected.displayName);
    final candidates = <PlannerStopOption>[selected];
    final seen = <String>{
      '${selected.operatorId}|${selected.routeId}|$selectedKey',
    };

    for (final option in search) {
      if (_plannerStationKey(option.displayName) != selectedKey) continue;

      final key = '${option.operatorId}|${option.routeId}|$selectedKey';
      if (seen.add(key)) candidates.add(option);
    }

    return candidates;
  }

  String _plannerStationKey(String value) {
    return cleanStationName(value)
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

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
      final departures =
          await TransitDepartureRepository(this).getDeparturesForStop(
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
              tripId: departure.tripId,
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

      final segment = await _store.tripSegment(
        operatorId: leg.operatorId,
        tripId: leg.tripId,
        fromStopId: leg.fromStop.stopId,
        toStopId: leg.toStop.stopId,
      );

      result.add(
        segment.isEmpty ? leg : leg.copyWithStops(segment),
      );

      if (result.length >= limit) {
        break;
      }
    }

    return result;
  }
}
