part of '../models.dart';

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
