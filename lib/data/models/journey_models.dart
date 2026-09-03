part of '../models.dart';

class PlannerStopOption {
  const PlannerStopOption({
    required this.displayName,
    required this.operatorId,
    required this.routeId,
    required this.routeShortName,
    required this.routeLongName,
    required this.routeType,
    required this.stops,
  });

  final String displayName;
  final String operatorId;
  final String routeId;
  final String routeShortName;
  final String routeLongName;
  final int routeType;

  /// A station can have multiple physical GTFS stop/platform records.
  final List<GtfsStop> stops;

  GtfsStop get primaryStop => stops.first;

  String get lineName {
    final longName = routeLongName.trim();

    if (longName.isNotEmpty) {
      return longName;
    }

    final shortName = routeShortName.trim();

    if (shortName.isNotEmpty) {
      return shortName;
    }

    return routeId;
  }
}

/// One transit leg.
///
/// A direct journey contains one JourneyLeg.
///
/// A standard one-transfer journey contains:
///
/// JourneyLeg A
/// -> JourneyTransfer
/// -> JourneyLeg B
class JourneyLeg {
  const JourneyLeg({
    required this.fromStop,
    required this.toStop,
    required this.operatorId,
    required this.tripId,
    required this.routeId,
    required this.routeLabel,
    required this.routeLongName,
    required this.headsign,
    required this.departureAt,
    required this.arrivalAt,
    required this.stopCount,
    required this.routeType,
    this.stops = const [],
  });

  final GtfsStop fromStop;
  final GtfsStop toStop;

  final String operatorId;
  final String tripId;
  final String routeId;
  final String routeLabel;
  final String routeLongName;
  final String headsign;

  final DateTime departureAt;
  final DateTime arrivalAt;

  final int stopCount;
  final int routeType;

  /// Ordered physical stops for this leg, including origin and destination.
  final List<GtfsStop> stops;

  JourneyLeg copyWithStops(List<GtfsStop> value) {
    return JourneyLeg(
      fromStop: fromStop,
      toStop: toStop,
      operatorId: operatorId,
      tripId: tripId,
      routeId: routeId,
      routeLabel: routeLabel,
      routeLongName: routeLongName,
      headsign: headsign,
      departureAt: departureAt,
      arrivalAt: arrivalAt,
      stopCount: stopCount,
      routeType: routeType,
      stops: value,
    );
  }

  Duration get duration {
    return arrivalAt.difference(departureAt);
  }
}

/// Walking / interchange connection between two transit stops.
///
/// This can represent:
///
/// - changing platform,
/// - changing rail line,
/// - walking between nearby stations,
/// - changing operator.
class JourneyTransfer {
  const JourneyTransfer({
    required this.fromStop,
    required this.toStop,
    required this.distanceMetres,
    required this.walkSeconds,
  });

  final GtfsStop fromStop;
  final GtfsStop toStop;

  final double distanceMetres;
  final int walkSeconds;

  int get walkMinutes {
    return (walkSeconds / 60).ceil();
  }
}

/// Complete planned journey.
///
/// Direct:
///
/// [leg]
///
/// One transfer:
///
/// [leg A] -> transfer -> [leg B]
///
/// The planner also supports changing line at the origin or destination.
class JourneyPlan {
  const JourneyPlan({
    required this.legs,
    this.beforeFirstLeg,
    this.betweenLegs,
    this.afterLastLeg,
  });

  final List<JourneyLeg> legs;

  /// Example:
  /// User selected KL Sentral Monorail but journey starts from
  /// KL Sentral Kelana Jaya Line.
  final JourneyTransfer? beforeFirstLeg;

  /// Normal interchange between leg 1 and leg 2.
  final JourneyTransfer? betweenLegs;

  /// Transfer/walk after the last transit leg.
  final JourneyTransfer? afterLastLeg;

  GtfsStop get fromStop => legs.first.fromStop;

  GtfsStop get toStop => legs.last.toStop;

  String get operatorId => legs.first.operatorId;

  String get routeId => legs.first.routeId;

  String get routeLabel => legs.first.routeLabel;

  String get routeLongName => legs.first.routeLongName;

  String get headsign => legs.first.headsign;

  int get routeType => legs.first.routeType;

  DateTime get departureAt => legs.first.departureAt;

  DateTime get arrivalAt => legs.last.arrivalAt;

  int get stopCount {
    return legs.fold(
      0,
      (total, leg) => total + leg.stopCount,
    );
  }

  int get transferCount {
    var count = 0;

    if (beforeFirstLeg != null) {
      count++;
    }

    if (betweenLegs != null) {
      count++;
    }

    if (afterLastLeg != null) {
      count++;
    }

    return count;
  }

  bool get isDirect {
    return legs.length == 1 && transferCount == 0;
  }

  DateTime get journeyStartAt {
    final transfer = beforeFirstLeg;

    if (transfer == null) {
      return departureAt;
    }

    return departureAt.subtract(
      Duration(
        seconds: transfer.walkSeconds,
      ),
    );
  }

  DateTime get journeyEndAt {
    final transfer = afterLastLeg;

    if (transfer == null) {
      return arrivalAt;
    }

    return arrivalAt.add(
      Duration(
        seconds: transfer.walkSeconds,
      ),
    );
  }

  Duration get duration {
    return journeyEndAt.difference(
      journeyStartAt,
    );
  }
}
