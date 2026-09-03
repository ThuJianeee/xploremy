part of '../transit_repository.dart';

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
