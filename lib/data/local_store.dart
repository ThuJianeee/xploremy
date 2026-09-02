import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/geo.dart';
import 'gtfs_api.dart';
import 'models.dart';

/// Offline GTFS cache.
///
/// Version 2 adds:
/// - calendar.txt
/// - calendar_dates.txt
/// - frequencies.txt
///
/// This allows the app to determine the correct service day and calculate
/// real scheduled departures instead of treating all timetable rows as daily.
class LocalGtfsStore {
  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();

    return openDatabase(
      p.join(
        dir,
        'xploremy_gtfs.db',
      ),
      version: 2,
      onCreate: (db, _) async {
        await _createSchema(db);
      },
      onUpgrade: (
        db,
        oldVersion,
        newVersion,
      ) async {
        if (oldVersion < 2) {
          await _createV2Tables(db);

          /// Existing V1 feed rows do not have trustworthy calendar data.
          /// Force users to re-download the official GTFS feed.
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

  Future<void> _createSchema(
    Database db,
  ) async {
    final batch = db.batch();

    batch.execute(
      '''
      CREATE TABLE stops (
        operator_id TEXT NOT NULL,
        stop_id TEXT NOT NULL,
        name TEXT NOT NULL,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        PRIMARY KEY (
          operator_id,
          stop_id
        )
      )
      ''',
    );

    batch.execute(
      '''
      CREATE INDEX idx_stops_bbox
      ON stops(
        lat,
        lon
      )
      ''',
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
        PRIMARY KEY (
          operator_id,
          route_id
        )
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
        PRIMARY KEY (
          operator_id,
          trip_id
        )
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
      '''
      CREATE INDEX idx_stop_times_stop
      ON stop_times(
        operator_id,
        stop_id,
        departure_seconds
      )
      ''',
    );

    batch.execute(
      '''
      CREATE INDEX idx_stop_times_trip
      ON stop_times(
        operator_id,
        trip_id,
        sequence
      )
      ''',
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

  Future<void> _createV2Tables(
    Database db,
  ) async {
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
        PRIMARY KEY (
          operator_id,
          service_id
        )
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
        PRIMARY KEY (
          operator_id,
          service_id,
          date
        )
      )
      ''',
    );

    batch.execute(
      '''
      CREATE INDEX IF NOT EXISTS idx_calendar_dates_date
      ON calendar_dates(
        operator_id,
        date
      )
      ''',
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
      '''
      CREATE INDEX IF NOT EXISTS idx_frequencies_trip
      ON frequencies(
        operator_id,
        trip_id
      )
      ''',
    );

    await batch.commit(
      noResult: true,
    );
  }

  // ==============================================================
  // FEED META
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
  // SAVE FEED
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
            'fetched_at': feed.fetchedAt.millisecondsSinceEpoch,
            'stop_count': feed.stops.length,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
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

    final latDelta = radiusMetres / 111320.0;

    final lonDelta = radiusMetres / 78000.0;

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

    if (operatorIds != null && operatorIds.isNotEmpty) {
      where.write(
        ' AND operator_id IN '
        '(${List.filled(operatorIds.length, '?').join(',')})',
      );

      args.addAll(operatorIds);
    }

    final rows = await db.query(
      'stops',
      where: where.toString(),
      whereArgs: args,
      limit: 2000,
    );

    final stops = rows
        .map(GtfsStop.fromMap)
        .map(
          (stop) => stop.copyWithDistance(
            haversineMetres(
              lat,
              lon,
              stop.lat,
              stop.lon,
            ),
          ),
        )
        .where(
          (stop) => stop.distanceMetres! <= radiusMetres,
        )
        .toList()
      ..sort(
        (a, b) => a.distanceMetres!.compareTo(
          b.distanceMetres!,
        ),
      );

    return stops.take(limit).toList();
  }

  // ==============================================================
  // NORMAL STOP SEARCH
  // ==============================================================

  Future<List<GtfsStop>> searchStops(
    String query, {
    int limit = 30,
  }) async {
    final db = await database;

    final clean = query.trim();

    if (clean.isEmpty) {
      return const [];
    }

    final rows = await db.query(
      'stops',
      where: 'name LIKE ?',
      whereArgs: [
        '%$clean%',
      ],
      orderBy: 'name COLLATE NOCASE ASC',
      limit: limit,
    );

    return rows.map(GtfsStop.fromMap).toList();
  }

  Future<GtfsStop?> stopById(
    String operatorId,
    String stopId,
  ) async {
    final db = await database;

    final rows = await db.query(
      'stops',
      where: 'operator_id = ? AND stop_id = ?',
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
  // ROUTE PLANNER STATION SEARCH
  // ==============================================================

  String _normalisePlannerStationName(
    String value,
  ) {
    var name = value.trim();

    name = name.replaceAll(
      RegExp(
        r'\s*-\s*REDONE\s*$',
        caseSensitive: false,
      ),
      '',
    );

    name = name.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return name.toUpperCase();
  }

  String _displayPlannerStationName(
    String value,
  ) {
    var name = value.trim();

    name = name.replaceAll(
      RegExp(
        r'\s*-\s*REDONE\s*$',
        caseSensitive: false,
      ),
      '',
    );

    name = name.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return name.isEmpty ? value : name;
  }

  Future<List<PlannerStopOption>> searchPlannerStops(
    String query, {
    int limit = 40,
  }) async {
    final db = await database;

    final clean = query.trim();

    if (clean.length < 2) {
      return const [];
    }

    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT
        s.operator_id,
        s.stop_id,
        s.name,
        s.lat,
        s.lon,
        r.route_id,
        r.short_name,
        r.long_name,
        r.type

      FROM stops s

      JOIN stop_times st
        ON st.operator_id = s.operator_id
        AND st.stop_id = s.stop_id

      JOIN trips t
        ON t.operator_id = st.operator_id
        AND t.trip_id = st.trip_id

      JOIN routes r
        ON r.operator_id = t.operator_id
        AND r.route_id = t.route_id

      WHERE s.name LIKE ?

      ORDER BY
        s.name COLLATE NOCASE ASC,
        r.long_name COLLATE NOCASE ASC,
        r.short_name COLLATE NOCASE ASC

      LIMIT 500
      ''',
      [
        '%$clean%',
      ],
    );

    return _groupPlannerRows(
      rows,
      limit: limit,
    );
  }

  Future<List<PlannerStopOption>> plannerOptionsForStop({
    required String operatorId,
    required String stopId,
  }) async {
    final selected = await stopById(
      operatorId,
      stopId,
    );

    if (selected == null) {
      return const [];
    }

    final searchName = _displayPlannerStationName(
      selected.name,
    );

    final options = await searchPlannerStops(
      searchName,
      limit: 80,
    );

    final exactMatches = options.where(
      (option) {
        if (option.operatorId != operatorId) {
          return false;
        }

        return option.stops.any(
          (stop) => stop.stopId == stopId && stop.operatorId == operatorId,
        );
      },
    ).toList();

    if (exactMatches.isNotEmpty) {
      return exactMatches;
    }

    final stationKey = _normalisePlannerStationName(
      selected.name,
    );

    return options.where(
      (option) {
        return option.operatorId == operatorId &&
            _normalisePlannerStationName(
                  option.displayName,
                ) ==
                stationKey;
      },
    ).toList();
  }

  List<PlannerStopOption> _groupPlannerRows(
    List<Map<String, Object?>> rows, {
    required int limit,
  }) {
    final grouped = <String, _PlannerGroup>{};

    for (final row in rows) {
      final operatorId = row['operator_id'] as String;

      final stopId = row['stop_id'] as String;

      final stopName = row['name'] as String;

      final routeId = (row['route_id'] as String?) ?? '';

      if (routeId.isEmpty) {
        continue;
      }

      final shortName = (row['short_name'] as String?) ?? '';

      final longName = (row['long_name'] as String?) ?? '';

      final routeType = (row['type'] as num?)?.toInt() ?? 3;

      final stationKey = _normalisePlannerStationName(
        stopName,
      );

      final groupKey = '$operatorId|$routeId|$stationKey';

      final stop = GtfsStop(
        operatorId: operatorId,
        stopId: stopId,
        name: stopName,
        lat: (row['lat'] as num).toDouble(),
        lon: (row['lon'] as num).toDouble(),
      );

      final group = grouped.putIfAbsent(
        groupKey,
        () => _PlannerGroup(
          displayName: _displayPlannerStationName(
            stopName,
          ),
          operatorId: operatorId,
          routeId: routeId,
          routeShortName: shortName,
          routeLongName: longName,
          routeType: routeType,
        ),
      );

      final alreadyAdded = group.stops.any(
        (existing) =>
            existing.operatorId == stop.operatorId &&
            existing.stopId == stop.stopId,
      );

      if (!alreadyAdded) {
        group.stops.add(stop);
      }
    }

    final options = grouped.values
        .where(
          (group) => group.stops.isNotEmpty,
        )
        .map(
          (group) => PlannerStopOption(
            displayName: group.displayName,
            operatorId: group.operatorId,
            routeId: group.routeId,
            routeShortName: group.routeShortName,
            routeLongName: group.routeLongName,
            routeType: group.routeType,
            stops: List.unmodifiable(group.stops),
          ),
        )
        .toList();

    options.sort(
      (a, b) {
        final stationCompare = a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );

        if (stationCompare != 0) {
          return stationCompare;
        }

        return a.lineName.toLowerCase().compareTo(
              b.lineName.toLowerCase(),
            );
      },
    );

    return options.take(limit).toList();
  }

  // ==============================================================
  // SERVICE CALENDAR
  // ==============================================================

  int _dateKey(
    DateTime date,
  ) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  String _weekdayColumn(
    DateTime date,
  ) {
    return switch (date.weekday) {
      DateTime.monday => 'monday',
      DateTime.tuesday => 'tuesday',
      DateTime.wednesday => 'wednesday',
      DateTime.thursday => 'thursday',
      DateTime.friday => 'friday',
      DateTime.saturday => 'saturday',
      DateTime.sunday => 'sunday',
      _ => 'monday',
    };
  }

  Future<Set<String>> activeServiceIds(
    String operatorId,
    DateTime serviceDate,
  ) async {
    final db = await database;

    final key = _dateKey(
      serviceDate,
    );

    final weekday = _weekdayColumn(
      serviceDate,
    );

    final baseRows = await db.rawQuery(
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
          (row) => row['service_id'] as String,
        )
        .toSet();

    final exceptionRows = await db.query(
      'calendar_dates',
      columns: [
        'service_id',
        'exception_type',
      ],
      where: 'operator_id = ? AND date = ?',
      whereArgs: [
        operatorId,
        key,
      ],
    );

    for (final row in exceptionRows) {
      final serviceId = row['service_id'] as String;

      final type = (row['exception_type'] as num).toInt();

      if (type == 1) {
        services.add(serviceId);
      }

      if (type == 2) {
        services.remove(serviceId);
      }
    }

    /// Some feeds do not supply calendar.txt and rely only on trips.
    ///
    /// In that case allow all known service IDs so offline demo data
    /// continues to function.
    if (services.isEmpty) {
      final calendarCount = Sqflite.firstIntValue(
            await db.rawQuery(
              '''
                  SELECT COUNT(*)

                  FROM calendar_services

                  WHERE operator_id = ?
                  ''',
              [
                operatorId,
              ],
            ),
          ) ??
          0;

      final exceptionCount = Sqflite.firstIntValue(
            await db.rawQuery(
              '''
                  SELECT COUNT(*)

                  FROM calendar_dates

                  WHERE operator_id = ?
                  ''',
              [
                operatorId,
              ],
            ),
          ) ??
          0;

      if (calendarCount == 0 && exceptionCount == 0) {
        final rows = await db.rawQuery(
          '''
          SELECT DISTINCT service_id

          FROM trips

          WHERE operator_id = ?
          ''',
          [
            operatorId,
          ],
        );

        services.addAll(
          rows
              .map(
                (row) => row['service_id'] as String?,
              )
              .whereType<String>()
              .where(
                (serviceId) => serviceId.isNotEmpty,
              ),
        );
      }
    }

    return services;
  }

  // ==============================================================
  // DEPARTURES
  // ==============================================================

  Future<List<Map<String, Object?>>> rawDepartures({
    required String operatorId,
    required String stopId,
    required DateTime serviceDate,
    required int fromSeconds,
    int limit = 25,
  }) async {
    final db = await database;

    final active = await activeServiceIds(
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
      await db.delete(table);
    }
  }
}

class _PlannerGroup {
  _PlannerGroup({
    required this.displayName,
    required this.operatorId,
    required this.routeId,
    required this.routeShortName,
    required this.routeLongName,
    required this.routeType,
  });

  final String displayName;
  final String operatorId;
  final String routeId;
  final String routeShortName;
  final String routeLongName;
  final int routeType;

  final List<GtfsStop> stops = [];
}
