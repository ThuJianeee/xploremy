part of '../transit_repository.dart';

extension TransitTransferPlanner on TransitRepository {
  Future<List<JourneyPlan>> _planOneTransferJourneys({
    required PlannerStopOption from,
    required PlannerStopOption to,
    int limit = 5,
  }) async {
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

      if (transferAtOrigin && !transferAtDestination) {
        final secondStart = _singleStopOption(
          to,
          candidate.secondStop,
        );

        final secondLegs = await TransitDirectPlanner(this)._directLegs(
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

      if (!transferAtOrigin && transferAtDestination) {
        final firstDestination = _singleStopOption(
          from,
          candidate.firstStop,
        );

        final firstLegs = await TransitDirectPlanner(this)._directLegs(
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

      if (transferAtOrigin && transferAtDestination) {
        continue;
      }

      final firstDestination = _singleStopOption(
        from,
        candidate.firstStop,
      );

      final secondStart = _singleStopOption(
        to,
        candidate.secondStop,
      );

      final firstLegs = await TransitDirectPlanner(this)._directLegs(
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

        final secondLegs = await TransitDirectPlanner(this)._directLegs(
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
    final walkingSeconds = (distanceMetres / 1.25).ceil();

    final total = walkingSeconds + 90;

    return total < 180 ? 180 : total;
  }
}
