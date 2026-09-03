part of '../local_store.dart';

extension LocalGtfsDepartureStore on LocalGtfsStore {
  Future<List<Map<String, Object?>>> rawDepartures({
    required String operatorId,
    required String stopId,
    required DateTime serviceDate,
    required int fromSeconds,
    int limit = 25,
  }) async {
    final db = await database;

    final active = await LocalGtfsCalendarStore(this).activeServiceIds(
      operatorId,
      serviceDate,
    );

    if (active.isEmpty) {
      return const [];
    }

    final placeholders = List.filled(
      active.length,
      '?',
    ).join(',');

    final serviceArgs = active.toList();

    final candidates = <Map<String, Object?>>[];

    // ------------------------------------------------------------
    // Normal scheduled trips
    // ------------------------------------------------------------

    final scheduledRows = await db.rawQuery(
      '''
      SELECT
        st.trip_id AS trip_id,
        st.departure_seconds AS departure_seconds,
        t.headsign AS headsign,
        t.service_id AS service_id,
        r.route_id AS route_id,
        r.short_name AS short_name,
        r.long_name AS long_name,
        r.type AS type

      FROM stop_times st

      JOIN trips t
        ON t.operator_id = st.operator_id
        AND t.trip_id = st.trip_id

      LEFT JOIN routes r
        ON r.operator_id = t.operator_id
        AND r.route_id = t.route_id

      WHERE st.operator_id = ?
        AND st.stop_id = ?
        AND t.service_id IN ($placeholders)
        AND st.departure_seconds >= ?

        AND EXISTS (
          SELECT 1

          FROM stop_times next_st

          WHERE next_st.operator_id =
                st.operator_id
            AND next_st.trip_id =
                st.trip_id
            AND next_st.sequence >
                st.sequence
        )

        AND NOT EXISTS (
          SELECT 1

          FROM frequencies f

          WHERE f.operator_id =
                st.operator_id
            AND f.trip_id =
                st.trip_id
        )

      ORDER BY st.departure_seconds ASC

      LIMIT ?
      ''',
      [
        operatorId,
        stopId,
        ...serviceArgs,
        fromSeconds,
        limit * 3,
      ],
    );

    candidates.addAll(
      scheduledRows,
    );

    // ------------------------------------------------------------
    // GTFS frequency trips
    // ------------------------------------------------------------

    final frequencyRows = await db.rawQuery(
      '''
      SELECT
        st.trip_id AS trip_id,

        st.departure_seconds
          AS template_departure_seconds,

        (
          SELECT MIN(first.departure_seconds)

          FROM stop_times first

          WHERE first.operator_id =
                st.operator_id
            AND first.trip_id =
                st.trip_id
        ) AS template_start_seconds,

        f.start_seconds
          AS frequency_start_seconds,

        f.end_seconds
          AS frequency_end_seconds,

        f.headway_seconds
          AS headway_seconds,

        t.headsign AS headsign,
        t.service_id AS service_id,
        r.route_id AS route_id,
        r.short_name AS short_name,
        r.long_name AS long_name,
        r.type AS type

      FROM stop_times st

      JOIN trips t
        ON t.operator_id = st.operator_id
        AND t.trip_id = st.trip_id

      JOIN frequencies f
        ON f.operator_id = st.operator_id
        AND f.trip_id = st.trip_id

      LEFT JOIN routes r
        ON r.operator_id = t.operator_id
        AND r.route_id = t.route_id

      WHERE st.operator_id = ?
        AND st.stop_id = ?
        AND t.service_id IN ($placeholders)

        AND EXISTS (
          SELECT 1

          FROM stop_times next_st

          WHERE next_st.operator_id =
                st.operator_id
            AND next_st.trip_id =
                st.trip_id
            AND next_st.sequence >
                st.sequence
        )
      ''',
      [
        operatorId,
        stopId,
        ...serviceArgs,
      ],
    );

    for (final row in frequencyRows) {
      final templateDeparture =
          (row['template_departure_seconds'] as num).toInt();

      final templateStart = (row['template_start_seconds'] as num?)?.toInt();

      final windowStart = (row['frequency_start_seconds'] as num).toInt();

      final windowEnd = (row['frequency_end_seconds'] as num).toInt();

      final headway = (row['headway_seconds'] as num).toInt();

      if (templateStart == null || headway <= 0) {
        continue;
      }

      final offset = templateDeparture - templateStart;

      final firstPossible = windowStart + offset;

      var occurrenceStart = windowStart;

      if (firstPossible < fromSeconds) {
        final steps = ((fromSeconds - firstPossible) / headway).ceil();

        occurrenceStart += steps * headway;
      }

      for (var tripStart = occurrenceStart;
          tripStart < windowEnd;
          tripStart += headway) {
        final departure = tripStart + offset;

        if (departure < fromSeconds) {
          continue;
        }

        candidates.add(
          {
            'trip_id': row['trip_id'],
            'departure_seconds': departure,
            'headsign': row['headsign'],
            'service_id': row['service_id'],
            'route_id': row['route_id'],
            'short_name': row['short_name'],
            'long_name': row['long_name'],
            'type': row['type'],
          },
        );

        if (candidates.length >= limit * 12) {
          break;
        }
      }
    }

    candidates.sort(
      (a, b) => (a['departure_seconds'] as num).toInt().compareTo(
            (b['departure_seconds'] as num).toInt(),
          ),
    );

    final seen = <String>{};

    final result = <Map<String, Object?>>[];

    for (final row in candidates) {
      final key = '${row['route_id']}|'
          '${row['headsign']}|'
          '${row['departure_seconds']}';

      if (!seen.add(key)) {
        continue;
      }

      result.add(row);

      if (result.length >= limit) {
        break;
      }
    }

    return result;
  }

  // ==============================================================
  // JOURNEY PLANNER HELPERS
  // ==============================================================

  /// Finds the stop positions and schedule times for two stops
  /// on exactly the same trip.
}
