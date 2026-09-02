// XploreMY data models.

class GtfsStop {
  const GtfsStop({
    required this.operatorId,
    required this.stopId,
    required this.name,
    required this.lat,
    required this.lon,
    this.distanceMetres,
  });

  final String operatorId;
  final String stopId;
  final String name;
  final double lat;
  final double lon;
  final double? distanceMetres;

  GtfsStop copyWithDistance(double metres) {
    return GtfsStop(
      operatorId: operatorId,
      stopId: stopId,
      name: name,
      lat: lat,
      lon: lon,
      distanceMetres: metres,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'operator_id': operatorId,
      'stop_id': stopId,
      'name': name,
      'lat': lat,
      'lon': lon,
    };
  }

  factory GtfsStop.fromMap(Map<String, Object?> m) {
    return GtfsStop(
      operatorId: m['operator_id'] as String,
      stopId: m['stop_id'] as String,
      name: m['name'] as String,
      lat: (m['lat'] as num).toDouble(),
      lon: (m['lon'] as num).toDouble(),
      distanceMetres:
          m['distance'] == null ? null : (m['distance'] as num).toDouble(),
    );
  }
}

class GtfsRoute {
  const GtfsRoute({
    required this.operatorId,
    required this.routeId,
    required this.shortName,
    required this.longName,
    required this.type,
    this.colorHex,
  });

  final String operatorId;
  final String routeId;
  final String shortName;
  final String longName;
  final int type;
  final String? colorHex;

  String get label => shortName.isNotEmpty ? shortName : routeId;

  Map<String, Object?> toMap() {
    return {
      'operator_id': operatorId,
      'route_id': routeId,
      'short_name': shortName,
      'long_name': longName,
      'type': type,
      'color': colorHex,
    };
  }

  factory GtfsRoute.fromMap(Map<String, Object?> m) {
    return GtfsRoute(
      operatorId: m['operator_id'] as String,
      routeId: m['route_id'] as String,
      shortName: (m['short_name'] as String?) ?? '',
      longName: (m['long_name'] as String?) ?? '',
      type: (m['type'] as num?)?.toInt() ?? 3,
      colorHex: m['color'] as String?,
    );
  }
}

class GtfsTrip {
  const GtfsTrip({
    required this.operatorId,
    required this.tripId,
    required this.routeId,
    required this.serviceId,
    required this.headsign,
  });

  final String operatorId;
  final String tripId;
  final String routeId;
  final String serviceId;
  final String headsign;

  Map<String, Object?> toMap() {
    return {
      'operator_id': operatorId,
      'trip_id': tripId,
      'route_id': routeId,
      'service_id': serviceId,
      'headsign': headsign,
    };
  }
}

class GtfsStopTime {
  const GtfsStopTime({
    required this.operatorId,
    required this.tripId,
    required this.stopId,
    required this.departureSeconds,
    required this.sequence,
  });

  final String operatorId;
  final String tripId;
  final String stopId;
  final int departureSeconds;
  final int sequence;

  Map<String, Object?> toMap() {
    return {
      'operator_id': operatorId,
      'trip_id': tripId,
      'stop_id': stopId,
      'departure_seconds': departureSeconds,
      'sequence': sequence,
    };
  }
}

/// One row from GTFS calendar.txt.
class GtfsCalendarService {
  const GtfsCalendarService({
    required this.operatorId,
    required this.serviceId,
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
    required this.startDate,
    required this.endDate,
  });

  final String operatorId;
  final String serviceId;

  final bool monday;
  final bool tuesday;
  final bool wednesday;
  final bool thursday;
  final bool friday;
  final bool saturday;
  final bool sunday;

  final int startDate;
  final int endDate;

  Map<String, Object?> toMap() {
    return {
      'operator_id': operatorId,
      'service_id': serviceId,
      'monday': monday ? 1 : 0,
      'tuesday': tuesday ? 1 : 0,
      'wednesday': wednesday ? 1 : 0,
      'thursday': thursday ? 1 : 0,
      'friday': friday ? 1 : 0,
      'saturday': saturday ? 1 : 0,
      'sunday': sunday ? 1 : 0,
      'start_date': startDate,
      'end_date': endDate,
    };
  }
}

/// One row from GTFS calendar_dates.txt.
class GtfsCalendarDate {
  const GtfsCalendarDate({
    required this.operatorId,
    required this.serviceId,
    required this.date,
    required this.exceptionType,
  });

  final String operatorId;
  final String serviceId;

  /// YYYYMMDD integer.
  final int date;

  /// 1 = added service.
  /// 2 = removed service.
  final int exceptionType;

  Map<String, Object?> toMap() {
    return {
      'operator_id': operatorId,
      'service_id': serviceId,
      'date': date,
      'exception_type': exceptionType,
    };
  }
}

/// GTFS frequency-based service.
class GtfsFrequency {
  const GtfsFrequency({
    required this.operatorId,
    required this.tripId,
    required this.startSeconds,
    required this.endSeconds,
    required this.headwaySeconds,
    this.exactTimes = false,
  });

  final String operatorId;
  final String tripId;
  final int startSeconds;
  final int endSeconds;
  final int headwaySeconds;
  final bool exactTimes;

  Map<String, Object?> toMap() {
    return {
      'operator_id': operatorId,
      'trip_id': tripId,
      'start_seconds': startSeconds,
      'end_seconds': endSeconds,
      'headway_seconds': headwaySeconds,
      'exact_times': exactTimes ? 1 : 0,
    };
  }
}

/// Upcoming departure shown in Stop Detail and Journey Planner.
class Departure {
  const Departure({
    required this.operatorId,
    this.routeId = '',
    required this.tripId,
    required this.routeLabel,
    required this.routeLongName,
    required this.headsign,
    required this.scheduledSeconds,
    required this.scheduledAt,
    required this.secondsUntil,
    required this.routeType,
    this.liveDelaySeconds,
  });

  final String operatorId;

  /// Optional default keeps older code compatible.
  final String routeId;

  final String tripId;
  final String routeLabel;
  final String routeLongName;
  final String headsign;

  final int scheduledSeconds;
  final DateTime scheduledAt;
  final int secondsUntil;
  final int routeType;

  /// Positive = delayed.
  /// Negative = early.
  /// Null = scheduled data only.
  final int? liveDelaySeconds;

  bool get hasLive => liveDelaySeconds != null;

  Reliability get reliability {
    final delay = liveDelaySeconds;

    if (delay == null) {
      return Reliability.scheduled;
    }

    if (delay.abs() <= 120) {
      return Reliability.onTime;
    }

    if (delay > 0) {
      return Reliability.delayed;
    }

    return Reliability.early;
  }
}

enum Reliability {
  scheduled,
  onTime,
  delayed,
  early,
}

/// GTFS realtime vehicle position.
class VehiclePosition {
  const VehiclePosition({
    required this.operatorId,
    required this.vehicleId,
    required this.lat,
    required this.lon,
    this.tripId,
    this.routeId,
    this.bearing,
    this.timestamp,
  });

  final String operatorId;
  final String vehicleId;

  final double lat;
  final double lon;

  final String? tripId;
  final String? routeId;
  final double? bearing;
  final DateTime? timestamp;
}

enum CrowdLevel {
  quiet,
  moderate,
  busy,
}

extension CrowdLevelLabel on CrowdLevel {
  String get label {
    return switch (this) {
      CrowdLevel.quiet => 'Usually quiet',
      CrowdLevel.moderate => 'Moderate',
      CrowdLevel.busy => 'Usually crowded',
    };
  }
}

/// One selectable station + route combination in Route Planner.
///
/// Example:
///
/// KL SENTRAL
/// LRT Kelana Jaya Line
///
/// and:
///
/// KL SENTRAL
/// KL Monorail Line
///
/// are separate PlannerStopOptions.
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
    required this.routeId,
    required this.routeLabel,
    required this.routeLongName,
    required this.headsign,
    required this.departureAt,
    required this.arrivalAt,
    required this.stopCount,
    required this.routeType,
  });

  final GtfsStop fromStop;
  final GtfsStop toStop;

  final String operatorId;
  final String routeId;
  final String routeLabel;
  final String routeLongName;
  final String headsign;

  final DateTime departureAt;
  final DateTime arrivalAt;

  final int stopCount;
  final int routeType;

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
