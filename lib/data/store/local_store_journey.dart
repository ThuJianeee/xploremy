part of '../local_store.dart';

extension LocalGtfsJourneyStore on LocalGtfsStore {
  Future<Map<String, int>?> tripStopWindow({
    required String operatorId,
    required String tripId,
    required String fromStopId,
    required String toStopId,
  }) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT
        origin.departure_seconds
          AS from_seconds,

        origin.sequence
          AS from_sequence,

        destination.departure_seconds
          AS to_seconds,

        destination.sequence
          AS to_sequence

      FROM stop_times origin

      JOIN stop_times destination
        ON destination.operator_id =
           origin.operator_id
        AND destination.trip_id =
           origin.trip_id

      WHERE origin.operator_id = ?
        AND origin.trip_id = ?
        AND origin.stop_id = ?
        AND destination.stop_id = ?
        AND destination.sequence >
            origin.sequence

      ORDER BY destination.sequence ASC

      LIMIT 1
      ''',
      [
        operatorId,
        tripId,
        fromStopId,
        toStopId,
      ],
    );

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;

    return {
      'from_seconds': (row['from_seconds'] as num).toInt(),
      'from_sequence': (row['from_sequence'] as num).toInt(),
      'to_seconds': (row['to_seconds'] as num).toInt(),
      'to_sequence': (row['to_sequence'] as num).toInt(),
    };
  }

  /// Every physical stop used by a specific route.
  ///
  /// Used by the transfer planner to find nearby interchanges between
  /// Route A and Route B.
  Future<List<GtfsStop>> routeStops({
    required String operatorId,
    required String routeId,
  }) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT
        s.operator_id,
        s.stop_id,
        s.name,
        s.lat,
        s.lon

      FROM stops s

      JOIN stop_times st
        ON st.operator_id = s.operator_id
        AND st.stop_id = s.stop_id

      JOIN trips t
        ON t.operator_id = st.operator_id
        AND t.trip_id = st.trip_id

      WHERE t.operator_id = ?
        AND t.route_id = ?

      ORDER BY s.name COLLATE NOCASE ASC
      ''',
      [
        operatorId,
        routeId,
      ],
    );

    return rows.map(GtfsStop.fromMap).toList();
  }

  /// Ordered route shape for a particular trip.
  Future<List<GtfsStop>> tripShape(
    String operatorId,
    String tripId,
  ) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT
        s.operator_id,
        s.stop_id,
        s.name,
        s.lat,
        s.lon

      FROM stop_times st

      JOIN stops s
        ON s.operator_id = st.operator_id
        AND s.stop_id = st.stop_id

      WHERE st.operator_id = ?
        AND st.trip_id = ?

      ORDER BY st.sequence ASC
      ''',
      [
        operatorId,
        tripId,
      ],
    );

    return rows.map(GtfsStop.fromMap).toList();
  }

  Future<int?> scheduledTimeForTripAtStop({
    required String operatorId,
    required String tripId,
    required String stopId,
  }) async {
    final db = await database;

    final rows = await db.query(
      'stop_times',
      columns: [
        'departure_seconds',
      ],
      where: 'operator_id = ? '
          'AND trip_id = ? '
          'AND stop_id = ?',
      whereArgs: [
        operatorId,
        tripId,
        stopId,
      ],
      orderBy: 'sequence ASC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return (rows.first['departure_seconds'] as num).toInt();
  }

  Future<List<GtfsStop>> tripSegment({
    required String operatorId,
    required String tripId,
    required String fromStopId,
    required String toStopId,
  }) async {
    final shape = await tripShape(operatorId, tripId);
    final fromIndex = shape.indexWhere((stop) => stop.stopId == fromStopId);
    if (fromIndex < 0) return const [];

    final toIndex = shape.indexWhere(
      (stop) => stop.stopId == toStopId,
      fromIndex + 1,
    );
    if (toIndex <= fromIndex) return const [];

    return shape.sublist(fromIndex, toIndex + 1);
  }

  // ==============================================================
  // CROWDING
  // ==============================================================

  Future<Map<int, int>> hourlyDensity(
    String operatorId,
    String stopId,
  ) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT
        (departure_seconds / 3600) % 24
          AS hour,

        COUNT(*) AS n

      FROM stop_times

      WHERE operator_id = ?
        AND stop_id = ?

      GROUP BY hour
      ''',
      [
        operatorId,
        stopId,
      ],
    );

    return {
      for (final row in rows)
        (row['hour'] as num).toInt(): (row['n'] as num).toInt(),
    };
  }

  // ==============================================================
  // CLEAR CACHE
  // ==============================================================

}
