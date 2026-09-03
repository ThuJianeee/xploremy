part of '../models.dart';

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
