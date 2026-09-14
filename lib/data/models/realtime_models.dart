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

  final String routeId;

  final String tripId;
  final String routeLabel;
  final String routeLongName;
  final String headsign;

  final int scheduledSeconds;
  final DateTime scheduledAt;
  final int secondsUntil;
  final int routeType;

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

enum ServiceActivityLevel {
  low,
  moderate,
  high,
}

extension ServiceActivityLevelLabel on ServiceActivityLevel {
  String get label {
    return switch (this) {
      ServiceActivityLevel.low => 'Low',
      ServiceActivityLevel.moderate => 'Moderate',
      ServiceActivityLevel.high => 'High',
    };
  }
}

class ServiceSpan {
  const ServiceSpan({required this.firstAt, required this.lastAt});
  final DateTime firstAt;
  final DateTime lastAt;
}
