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

  /// Populated by nearby-stop queries.
  final double? distanceMetres;

  GtfsStop copyWithDistance(double metres) => GtfsStop(
        operatorId: operatorId,
        stopId: stopId,
        name: name,
        lat: lat,
        lon: lon,
        distanceMetres: metres,
      );

  Map<String, Object?> toMap() => {
        'operator_id': operatorId,
        'stop_id': stopId,
        'name': name,
        'lat': lat,
        'lon': lon,
      };

  factory GtfsStop.fromMap(Map<String, Object?> m) => GtfsStop(
        operatorId: m['operator_id'] as String,
        stopId: m['stop_id'] as String,
        name: m['name'] as String,
        lat: (m['lat'] as num).toDouble(),
        lon: (m['lon'] as num).toDouble(),
        distanceMetres: m['distance'] == null
            ? null
            : (m['distance'] as num).toDouble(),
      );
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

  /// GTFS route_type: 0 tram, 1 metro, 2 rail, 3 bus…
  final int type;
  final String? colorHex;

  String get label => shortName.isNotEmpty ? shortName : routeId;

  Map<String, Object?> toMap() => {
        'operator_id': operatorId,
        'route_id': routeId,
        'short_name': shortName,
        'long_name': longName,
        'type': type,
        'color': colorHex,
      };

  factory GtfsRoute.fromMap(Map<String, Object?> m) => GtfsRoute(
        operatorId: m['operator_id'] as String,
        routeId: m['route_id'] as String,
        shortName: (m['short_name'] as String?) ?? '',
        longName: (m['long_name'] as String?) ?? '',
        type: (m['type'] as num?)?.toInt() ?? 3,
        colorHex: m['color'] as String?,
      );
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

  Map<String, Object?> toMap() => {
        'operator_id': operatorId,
        'trip_id': tripId,
        'route_id': routeId,
        'service_id': serviceId,
        'headsign': headsign,
      };
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

  Map<String, Object?> toMap() => {
        'operator_id': operatorId,
        'trip_id': tripId,
        'stop_id': stopId,
        'departure_seconds': departureSeconds,
        'sequence': sequence,
      };
}

/// A single upcoming departure shown on the Stop Detail screen.
class Departure {
  const Departure({
    required this.operatorId,
    required this.tripId,
    required this.routeLabel,
    required this.routeLongName,
    required this.headsign,
    required this.scheduledSeconds,
    required this.secondsUntil,
    required this.routeType,
    this.liveDelaySeconds,
  });

  final String operatorId;
  final String tripId;
  final String routeLabel;
  final String routeLongName;
  final String headsign;
  final int scheduledSeconds;
  final int secondsUntil;
  final int routeType;

  /// Positive = running late, negative = early. Null = no live data.
  final int? liveDelaySeconds;

  bool get hasLive => liveDelaySeconds != null;

  /// Reliability layer: how this vehicle is tracking against schedule.
  Reliability get reliability {
    final d = liveDelaySeconds;
    if (d == null) return Reliability.scheduled;
    if (d.abs() <= 120) return Reliability.onTime;
    if (d > 0) return Reliability.delayed;
    return Reliability.early;
  }
}

enum Reliability { scheduled, onTime, delayed, early }

/// GTFS-realtime vehicle position.
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

/// Crowding heuristic derived from how many trips serve a stop in an hour.
enum CrowdLevel { quiet, moderate, busy }

extension CrowdLevelLabel on CrowdLevel {
  String get label => switch (this) {
        CrowdLevel.quiet => 'Usually quiet',
        CrowdLevel.moderate => 'Moderate',
        CrowdLevel.busy => 'Usually crowded',
      };
}
