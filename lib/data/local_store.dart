import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/geo.dart';
import 'gtfs_api.dart';
import 'models.dart';

/// Offline GTFS cache.
///
/// Version 2 adds calendar/calendar_dates/frequencies so departures are
/// service-day aware and Rapid Rail frequency feeds are expanded correctly.
class LocalGtfsStore {
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'xploremy_gtfs.db'),
      version: 2,
      onCreate: (db, _) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createV2Tables(db);

          // Existing v1 rows do not contain service calendars/frequencies and
          // therefore cannot produce trustworthy departures.
          for (final table in [
            'stops',
            'routes',
            'trips',
            'stop_times',
          ]) {
            await db.delete(table);
          }

          await db.delete('feed_meta');
        }
      },
    );
  }

  // ==============================================================
  // DATABASE SCHEMA
  // ==============================================================

  Future<void> _createSchema(Database db) async {
    final batch = db.batch();

    batch.execute(
      '''
      CREATE TABLE stops (
        operator_id TEXT NOT NULL,
        stop_id TEXT NOT NULL,
        name TEXT NOT NULL,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        PRIMARY KEY (operator_id, stop_id)
      )
      ''',
    );

    batch.execute(
      'CREATE INDEX idx_stops_bbox ON stops(lat, lon)',
    );

    batch.execute(
      '''
      CREATE TABLE routes (
        operator_id TEXT NOT NULL,
        route_id TEXT NOT NULL,
        short_name TEXT,
        long_name TEXT,
        type INTEGER,
        color TEXT,
        PRIMARY KEY (operator_id, route_id)
      )
      ''',
    );

    batch.execute(
      '''
      CREATE TABLE trips (
        operator_id TEXT NOT NULL,
        trip_id TEXT NOT NULL,
        route_id TEXT NOT NULL,
        service_id TEXT,
        headsign TEXT,
        PRIMARY KEY (operator_id, trip_id)
      )
      ''',
    );

    batch.execute(
      '''
      CREATE TABLE stop_times (
        operator_id TEXT NOT NULL,
        trip_id TEXT NOT NULL,
        stop_id TEXT NOT NULL,
        departure_seconds INTEGER NOT NULL,
        sequence INTEGER NOT NULL
      )
      ''',
    );

    batch.execute(
      'CREATE INDEX idx_stop_times_stop '
          'ON stop_times(operator_id, stop_id, departure_seconds)',
    );

    batch.execute(
      'CREATE INDEX idx_stop_times_trip '
          'ON stop_times(operator_id, trip_id, sequence)',
    );

    batch.execute(
      '''
      CREATE TABLE feed_meta (
        operator_id TEXT PRIMARY KEY,
        fetched_at INTEGER NOT NULL,
        stop_count INTEGER NOT NULL
      )
      ''',
    );

    await batch.commit(
      noResult: true,
    );

    await _createV2Tables(db);
  }

  Future<void> _createV2Tables(Database db) async {
    final batch = db.batch();

    batch.execute(
      '''
      CREATE TABLE IF NOT EXISTS calendar_services (
        operator_id TEXT NOT NULL,
        service_id TEXT NOT NULL,
        monday INTEGER NOT NULL,
        tuesday INTEGER NOT NULL,
        wednesday INTEGER NOT NULL,
        thursday INTEGER NOT NULL,
        friday INTEGER NOT NULL,
        saturday INTEGER NOT NULL,
        sunday INTEGER NOT NULL,
        start_date INTEGER NOT NULL,
        end_date INTEGER NOT NULL,
        PRIMARY KEY (operator_id, service_id)
      )
      ''',
    );

    batch.execute(
      '''
      CREATE TABLE IF NOT EXISTS calendar_dates (
        operator_id TEXT NOT NULL,
        service_id TEXT NOT NULL,
        date INTEGER NOT NULL,
        exception_type INTEGER NOT NULL,
        PRIMARY KEY (operator_id, service_id, date)
      )
      ''',
    );

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_calendar_dates_date '
          'ON calendar_dates(operator_id, date)',
    );

    batch.execute(
      '''
      CREATE TABLE IF NOT EXISTS frequencies (
        operator_id TEXT NOT NULL,
        trip_id TEXT NOT NULL,
        start_seconds INTEGER NOT NULL,
        end_seconds INTEGER NOT NULL,
        headway_seconds INTEGER NOT NULL,
        exact_times INTEGER NOT NULL DEFAULT 0
      )
      ''',
    );

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_frequencies_trip '
          'ON frequencies(operator_id, trip_id)',
    );

    await batch.commit(
      noResult: true,
    );
  }

  // ==============================================================
  // FEED INFORMATION
  // ==============================================================

  Future<DateTime?> lastSync(
      String operatorId,
      ) async {
    final db = await database;

    final rows = await db.query(
      'feed_meta',
      where: 'operator_id = ?',
      whereArgs: [
        operatorId,
      ],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(
      rows.first['fetched_at'] as int,
    );
  }

  Future<List<String>> cachedOperatorIds() async {
    final db = await database;

    final rows = await db.query(
      'feed_meta',
      columns: [
        'operator_id',
      ],
    );

    return rows
        .map(
          (row) => row['operator_id'] as String,
    )
        .toList();
  }

  // ==============================================================
  // SAVE GTFS FEED
  // ==============================================================

  Future<void> saveFeed(
      GtfsStaticFeed feed,
      ) async {
    final db = await database;

    await db.transaction(
          (txn) async {
        for (final table in [
          'stops',
          'routes',
          'trips',
          'stop_times',
          'calendar_services',
          'calendar_dates',
          'frequencies',
        ]) {
          await txn.delete(
            table,
            where: 'operator_id = ?',
            whereArgs: [
              feed.operatorId,
            ],
          );
        }

        Future<void> insertAll(
            String table,
            Iterable<Map<String, Object?>> rows,
            ) async {
          var batch = txn.batch();
          var count = 0;

          for (final row in rows) {
            batch.insert(
              table,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            count++;

            if (count % 800 == 0) {
              await batch.commit(
                noResult: true,
              );

              batch = txn.batch();
            }
          }

          await batch.commit(
            noResult: true,
          );
        }

        await insertAll(
          'stops',
          feed.stops.map(
                (item) => item.toMap(),
          ),
        );

        await insertAll(
          'routes',
          feed.routes.map(
                (item) => item.toMap(),
          ),
        );

        await insertAll(
          'trips',
          feed.trips.map(
                (item) => item.toMap(),
          ),
        );

        await insertAll(
          'stop_times',
          feed.stopTimes.map(
                (item) => item.toMap(),
          ),
        );

        await insertAll(
          'calendar_services',
          feed.calendar.map(
                (item) => item.toMap(),
          ),
        );

        await insertAll(
          'calendar_dates',
          feed.calendarDates.map(
                (item) => item.toMap(),
          ),
        );

        await insertAll(
          'frequencies',
          feed.frequencies.map(
                (item) => item.toMap(),
          ),
        );

        await txn.insert(
          'feed_meta',
          {
            'operator_id': feed.operatorId,
            'fetched_at':
            feed.fetchedAt.millisecondsSinceEpoch,
            'stop_count': feed.stops.length,
          },
          conflictAlgorithm:
          ConflictAlgorithm.replace,
        );
      },
    );
  }

  // ==============================================================
  // NEARBY STOPS
  // ==============================================================

  Future<List<GtfsStop>> nearbyStops({
    required double lat,
    required double lon,
    required double radiusMetres,
    List<String>? operatorIds,
    int limit = 40,
  }) async {
    final db = await database;

    final latDelta =
        radiusMetres / 111320.0;

    final lonDelta =
        radiusMetres / 78000.0;

    final where = StringBuffer(
      'lat BETWEEN ? AND ? '
          'AND lon BETWEEN ? AND ?',
    );

    final args = <Object?>[
      lat - latDelta,
      lat + latDelta,
      lon - lonDelta,
      lon + lonDelta,
    ];

    if (operatorIds != null &&
        operatorIds.isNotEmpty) {
      where.write(
        ' AND operator_id IN '
            '(${List.filled(operatorIds.length, '?').join(',')})',
      );

      args.addAll(
        operatorIds,
      );
    }

    final rows = await db.query(
      'stops',
      where: where.toString(),
      whereArgs: args,
      limit: 2000,
    );

    final stops = rows
        .map(
      GtfsStop.fromMap,
    )
        .map(
          (stop) =>
          stop.copyWithDistance(
            haversineMetres(
              lat,
              lon,
              stop.lat,
              stop.lon,
            ),
          ),
    )
        .where(
          (stop) =>
      stop.distanceMetres! <=
          radiusMetres,
    )
        .toList()
      ..sort(
            (a, b) =>
            a.distanceMetres!.compareTo(
              b.distanceMetres!,
            ),
      );

    return stops
        .take(limit)
        .toList();
  }

  // ==============================================================
  // SEARCH
  // ==============================================================

  Future<List<GtfsStop>> searchStops(
      String query, {
        int limit = 30,
      }) async {
    final db = await database;

    final rows = await db.query(
      'stops',
      where: 'name LIKE ?',
      whereArgs: [
        '%$query%',
      ],
      limit: limit,
    );

    return rows
        .map(
      GtfsStop.fromMap,
    )
        .toList();
  }

  // ==============================================================
  // GET STOP
  // ==============================================================

  Future<GtfsStop?> stopById(
      String operatorId,
      String stopId,
      ) async {
    final db = await database;

    final rows = await db.query(
      'stops',
      where:
      'operator_id = ? AND stop_id = ?',
      whereArgs: [
        operatorId,
        stopId,
      ],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return GtfsStop.fromMap(
      rows.first,
    );
  }

  // ==============================================================
  // SERVICE CALENDAR
  // ==============================================================

  int _dateKey(
      DateTime date,
      ) {
    return date.year * 10000 +
        date.month * 100 +
        date.day;
  }

  String _weekdayColumn(
      DateTime date,
      ) =>
      switch (date.weekday) {
        DateTime.monday =>
        'monday',
        DateTime.tuesday =>
        'tuesday',
        DateTime.wednesday =>
        'wednesday',
        DateTime.thursday =>
        'thursday',
        DateTime.friday =>
        'friday',
        DateTime.saturday =>
        'saturday',
        DateTime.sunday =>
        'sunday',
        _ => 'monday',
      };

  /// Returns active GTFS service IDs for the requested service day.
  ///
  /// It first checks calendar.txt and then applies calendar_dates.txt
  /// exceptions.
  Future<Set<String>>
  activeServiceIds(
      String operatorId,
      DateTime serviceDate,
      ) async {
    final db = await database;

    final key =
    _dateKey(serviceDate);

    final weekday =
    _weekdayColumn(serviceDate);

    final baseRows =
    await db.rawQuery(
      '''
      SELECT service_id
      FROM calendar_services
      WHERE operator_id = ?
        AND start_date <= ?
        AND end_date >= ?
        AND $weekday = 1
      ''',
      [
        operatorId,
        key,
        key,
      ],
    );

    final services = baseRows
        .map(
          (row) =>
      row['service_id']
      as String,
    )
        .toSet();

    final exceptionRows =
    await db.query(
      'calendar_dates',
      columns: [
        'service_id',
        'exception_type',
      ],
      where:
      'operator_id = ? AND date = ?',
      whereArgs: [
        operatorId,
        key,
      ],
    );

    for (final row
    in exceptionRows) {
      final serviceId =
      row['service_id']
      as String;

      final type =
      (row['exception_type']
      as num)
          .toInt();

      if (type == 1) {
        services.add(
          serviceId,
        );
      } else if (type == 2) {
        services.remove(
          serviceId,
        );
      }
    }

    // Some mock/non-standard feeds may not include calendar information.
    // In that case we allow all service IDs from trips.
    if (services.isEmpty) {
      final calendarCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) '
                  'FROM calendar_services '
                  'WHERE operator_id = ?',
              [
                operatorId,
              ],
            ),
          ) ??
              0;

      final exceptionCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) '
                  'FROM calendar_dates '
                  'WHERE operator_id = ?',
              [
                operatorId,
              ],
            ),
          ) ??
              0;

      if (calendarCount == 0 &&
          exceptionCount == 0) {
        final rows =
        await db.rawQuery(
          'SELECT DISTINCT service_id '
              'FROM trips '
              'WHERE operator_id = ?',
          [
            operatorId,
          ],
        );

        services.addAll(
          rows
              .map(
                (row) =>
            row['service_id']
            as String?,
          )
              .whereType<String>()
              .where(
                (serviceId) =>
            serviceId
                .isNotEmpty,
          ),
        );
      }
    }

    return services;
  }

  // ==============================================================
  // DEPARTURES
  // ==============================================================

  /// Returns upcoming departures for one GTFS service day.
  ///
  /// Important:
  /// - calendar / calendar_dates are respected.
  /// - frequency-based trips are expanded.
  /// - terminal arrivals are NOT shown as departures.
  /// - duplicate physical departures are removed.
  Future<List<Map<String, Object?>>>
  rawDepartures({
    required String operatorId,
    required String stopId,
    required DateTime serviceDate,
    required int fromSeconds,
    int limit = 25,
  }) async {
    final db = await database;

    final active =
    await activeServiceIds(
      operatorId,
      serviceDate,
    );

    if (active.isEmpty) {
      return const [];
    }

    final placeholders =
    List.filled(
      active.length,
      '?',
    ).join(',');

    final serviceArgs =
    active.toList();

    final candidates =
    <Map<String, Object?>>[];

    // ----------------------------------------------------------
    // Normal scheduled trips
    // ----------------------------------------------------------

    final scheduledRows =
    await db.rawQuery(
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

        -- Only treat this stop as a departure when the trip
        -- continues to another stop afterwards.
        AND EXISTS (
          SELECT 1
          FROM stop_times next_st
          WHERE next_st.operator_id = st.operator_id
            AND next_st.trip_id = st.trip_id
            AND next_st.sequence > st.sequence
        )

        -- Frequency trips are handled separately below.
        AND NOT EXISTS (
          SELECT 1
          FROM frequencies f
          WHERE f.operator_id = st.operator_id
            AND f.trip_id = st.trip_id
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

    // ----------------------------------------------------------
    // Frequency-based trips
    // ----------------------------------------------------------

    final frequencyRows =
    await db.rawQuery(
      '''
      SELECT
        st.trip_id AS trip_id,

        st.departure_seconds
          AS template_departure_seconds,

        (
          SELECT MIN(
            first.departure_seconds
          )
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
        ON t.operator_id =
           st.operator_id
        AND t.trip_id =
           st.trip_id

      JOIN frequencies f
        ON f.operator_id =
           st.operator_id
        AND f.trip_id =
           st.trip_id

      LEFT JOIN routes r
        ON r.operator_id =
           t.operator_id
        AND r.route_id =
           t.route_id

      WHERE st.operator_id = ?
        AND st.stop_id = ?
        AND t.service_id IN ($placeholders)

        -- Prevent terminal arrivals from being shown as departures.
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

    // Expand frequency templates into actual departures.
    for (final row
    in frequencyRows) {
      final templateDeparture =
      (row['template_departure_seconds']
      as num)
          .toInt();

      final templateStart =
      (row['template_start_seconds']
      as num?)
          ?.toInt();

      final windowStart =
      (row['frequency_start_seconds']
      as num)
          .toInt();

      final windowEnd =
      (row['frequency_end_seconds']
      as num)
          .toInt();

      final headway =
      (row['headway_seconds']
      as num)
          .toInt();

      if (templateStart == null ||
          headway <= 0) {
        continue;
      }

      final offset =
          templateDeparture -
              templateStart;

      final firstPossible =
          windowStart + offset;

      var occurrenceStart =
          windowStart;

      if (firstPossible <
          fromSeconds) {
        final steps =
        ((fromSeconds -
            firstPossible) /
            headway)
            .ceil();

        final safeSteps =
        steps < 0
            ? 0
            : steps;

        occurrenceStart +=
            safeSteps * headway;
      }

      for (var tripStart =
          occurrenceStart;
      tripStart < windowEnd;
      tripStart += headway) {
        final departure =
            tripStart + offset;

        if (departure <
            fromSeconds) {
          continue;
        }

        candidates.add(
          {
            'trip_id':
            row['trip_id'],
            'departure_seconds':
            departure,
            'headsign':
            row['headsign'],
            'service_id':
            row['service_id'],
            'route_id':
            row['route_id'],
            'short_name':
            row['short_name'],
            'long_name':
            row['long_name'],
            'type':
            row['type'],
          },
        );

        // Prevent very large frequency feeds from expanding unnecessarily.
        if (candidates.length >=
            limit * 12) {
          break;
        }
      }
    }

    // ----------------------------------------------------------
    // Sort
    // ----------------------------------------------------------

    candidates.sort(
          (a, b) =>
          (a['departure_seconds']
          as num)
              .toInt()
              .compareTo(
            (b['departure_seconds']
            as num)
                .toInt(),
          ),
    );

    // ----------------------------------------------------------
    // Remove duplicate physical departures
    // ----------------------------------------------------------

    final seen =
    <String>{};

    final deduped =
    <Map<String, Object?>>[];

    for (final row
    in candidates) {
      final key =
          '${row['route_id']}|'
          '${row['headsign']}|'
          '${row['departure_seconds']}';

      if (!seen.add(key)) {
        continue;
      }

      deduped.add(
        row,
      );

      if (deduped.length >=
          limit) {
        break;
      }
    }

    return deduped;
  }

  // ==============================================================
  // TRIP SHAPE
  // ==============================================================

  Future<List<GtfsStop>> tripShape(
      String operatorId,
      String tripId,
      ) async {
    final db = await database;

    final rows =
    await db.rawQuery(
      '''
      SELECT
        s.operator_id,
        s.stop_id,
        s.name,
        s.lat,
        s.lon

      FROM stop_times st

      JOIN stops s
        ON s.operator_id =
           st.operator_id
        AND s.stop_id =
           st.stop_id

      WHERE st.operator_id = ?
        AND st.trip_id = ?

      ORDER BY st.sequence ASC
      ''',
      [
        operatorId,
        tripId,
      ],
    );

    return rows
        .map(
      GtfsStop.fromMap,
    )
        .toList();
  }

  // ==============================================================
  // SCHEDULED TIME FOR TRIP AT STOP
  // ==============================================================

  Future<int?>
  scheduledTimeForTripAtStop({
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
      where:
      'operator_id = ? '
          'AND trip_id = ? '
          'AND stop_id = ?',
      whereArgs: [
        operatorId,
        tripId,
        stopId,
      ],
      orderBy:
      'sequence ASC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return (rows.first[
    'departure_seconds']
    as num)
        .toInt();
  }

  // ==============================================================
  // CROWD DENSITY
  // ==============================================================

  Future<Map<int, int>>
  hourlyDensity(
      String operatorId,
      String stopId,
      ) async {
    final db = await database;

    final rows =
    await db.rawQuery(
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
        (row['hour'] as num)
            .toInt():
        (row['n'] as num)
            .toInt(),
    };
  }

  // ==============================================================
  // CLEAR CACHE
  // ==============================================================

  Future<void> clear() async {
    final db = await database;

    for (final table in [
      'stops',
      'routes',
      'trips',
      'stop_times',
      'calendar_services',
      'calendar_dates',
      'frequencies',
      'feed_meta',
    ]) {
      await db.delete(
        table,
      );
    }
  }
}