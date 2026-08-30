import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/geo.dart';
import 'gtfs_api.dart';
import 'models.dart';

/// Offline cache (SDG 9.c): the whole static timetable lives in SQLite so the
/// app still works on patchy connectivity in secondary cities.
class LocalGtfsStore {
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'xploremy_gtfs.db'),
      version: 1,
      onCreate: (db, _) async {
        final batch = db.batch();
        batch.execute('''
          CREATE TABLE stops (
            operator_id TEXT NOT NULL,
            stop_id TEXT NOT NULL,
            name TEXT NOT NULL,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            PRIMARY KEY (operator_id, stop_id)
          )''');
        batch.execute('CREATE INDEX idx_stops_bbox ON stops(lat, lon)');
        batch.execute('''
          CREATE TABLE routes (
            operator_id TEXT NOT NULL,
            route_id TEXT NOT NULL,
            short_name TEXT,
            long_name TEXT,
            type INTEGER,
            color TEXT,
            PRIMARY KEY (operator_id, route_id)
          )''');
        batch.execute('''
          CREATE TABLE trips (
            operator_id TEXT NOT NULL,
            trip_id TEXT NOT NULL,
            route_id TEXT NOT NULL,
            service_id TEXT,
            headsign TEXT,
            PRIMARY KEY (operator_id, trip_id)
          )''');
        batch.execute('''
          CREATE TABLE stop_times (
            operator_id TEXT NOT NULL,
            trip_id TEXT NOT NULL,
            stop_id TEXT NOT NULL,
            departure_seconds INTEGER NOT NULL,
            sequence INTEGER NOT NULL
          )''');
        batch.execute(
            'CREATE INDEX idx_stop_times_stop ON stop_times(operator_id, stop_id, departure_seconds)');
        batch.execute(
            'CREATE INDEX idx_stop_times_trip ON stop_times(operator_id, trip_id, sequence)');
        batch.execute('''
          CREATE TABLE feed_meta (
            operator_id TEXT PRIMARY KEY,
            fetched_at INTEGER NOT NULL,
            stop_count INTEGER NOT NULL
          )''');
        await batch.commit(noResult: true);
      },
    );
  }

  Future<DateTime?> lastSync(String operatorId) async {
    final db = await database;
    final rows = await db.query('feed_meta',
        where: 'operator_id = ?', whereArgs: [operatorId], limit: 1);
    if (rows.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(rows.first['fetched_at'] as int);
  }

  Future<List<String>> cachedOperatorIds() async {
    final db = await database;
    final rows = await db.query('feed_meta', columns: ['operator_id']);
    return rows.map((r) => r['operator_id'] as String).toList();
  }

  /// Replaces everything stored for one operator inside a single transaction.
  Future<void> saveFeed(GtfsStaticFeed feed) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in ['stops', 'routes', 'trips', 'stop_times']) {
        await txn.delete(table,
            where: 'operator_id = ?', whereArgs: [feed.operatorId]);
      }

      Future<void> insertAll(
          String table, Iterable<Map<String, Object?>> rows) async {
        var batch = txn.batch();
        var n = 0;
        for (final row in rows) {
          batch.insert(table, row,
              conflictAlgorithm: ConflictAlgorithm.replace);
          if (++n % 800 == 0) {
            await batch.commit(noResult: true);
            batch = txn.batch();
          }
        }
        await batch.commit(noResult: true);
      }

      await insertAll('stops', feed.stops.map((e) => e.toMap()));
      await insertAll('routes', feed.routes.map((e) => e.toMap()));
      await insertAll('trips', feed.trips.map((e) => e.toMap()));
      await insertAll('stop_times', feed.stopTimes.map((e) => e.toMap()));

      await txn.insert(
        'feed_meta',
        {
          'operator_id': feed.operatorId,
          'fetched_at': feed.fetchedAt.millisecondsSinceEpoch,
          'stop_count': feed.stops.length,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Nearby stops, bounding-box pre-filtered in SQL then ranked by haversine.
  Future<List<GtfsStop>> nearbyStops({
    required double lat,
    required double lon,
    required double radiusMetres,
    List<String>? operatorIds,
    int limit = 40,
  }) async {
    final db = await database;
    final latDelta = radiusMetres / 111320.0;
    final lonDelta = radiusMetres / 78000.0; // ~ at Malaysian latitudes

    final where = StringBuffer('lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?');
    final args = <Object?>[
      lat - latDelta,
      lat + latDelta,
      lon - lonDelta,
      lon + lonDelta,
    ];
    if (operatorIds != null && operatorIds.isNotEmpty) {
      where.write(
          ' AND operator_id IN (${List.filled(operatorIds.length, '?').join(',')})');
      args.addAll(operatorIds);
    }

    final rows = await db.query('stops',
        where: where.toString(), whereArgs: args, limit: 2000);

    final stops = rows
        .map(GtfsStop.fromMap)
        .map((s) => s.copyWithDistance(
            haversineMetres(lat, lon, s.lat, s.lon)))
        .where((s) => s.distanceMetres! <= radiusMetres)
        .toList()
      ..sort((a, b) => a.distanceMetres!.compareTo(b.distanceMetres!));

    return stops.take(limit).toList();
  }

  Future<List<GtfsStop>> searchStops(String query, {int limit = 30}) async {
    final db = await database;
    final rows = await db.query('stops',
        where: 'name LIKE ?', whereArgs: ['%$query%'], limit: limit);
    return rows.map(GtfsStop.fromMap).toList();
  }

  Future<GtfsStop?> stopById(String operatorId, String stopId) async {
    final db = await database;
    final rows = await db.query('stops',
        where: 'operator_id = ? AND stop_id = ?',
        whereArgs: [operatorId, stopId],
        limit: 1);
    return rows.isEmpty ? null : GtfsStop.fromMap(rows.first);
  }

  /// Upcoming departures for a stop, joined with trips + routes.
  Future<List<Map<String, Object?>>> rawDepartures({
    required String operatorId,
    required String stopId,
    required int fromSeconds,
    int limit = 25,
  }) async {
    final db = await database;
    return db.rawQuery('''
      SELECT st.trip_id       AS trip_id,
             st.departure_seconds AS departure_seconds,
             t.headsign       AS headsign,
             r.route_id       AS route_id,
             r.short_name     AS short_name,
             r.long_name      AS long_name,
             r.type           AS type
      FROM stop_times st
      JOIN trips  t ON t.operator_id = st.operator_id AND t.trip_id = st.trip_id
      LEFT JOIN routes r ON r.operator_id = t.operator_id AND r.route_id = t.route_id
      WHERE st.operator_id = ? AND st.stop_id = ? AND st.departure_seconds >= ?
      ORDER BY st.departure_seconds ASC
      LIMIT ?
    ''', [operatorId, stopId, fromSeconds, limit]);
  }

  /// Ordered stop list of a trip — used to draw the static route line.
  Future<List<GtfsStop>> tripShape(String operatorId, String tripId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT s.operator_id, s.stop_id, s.name, s.lat, s.lon
      FROM stop_times st
      JOIN stops s ON s.operator_id = st.operator_id AND s.stop_id = st.stop_id
      WHERE st.operator_id = ? AND st.trip_id = ?
      ORDER BY st.sequence ASC
    ''', [operatorId, tripId]);
    return rows.map(GtfsStop.fromMap).toList();
  }

  /// Departures per hour at a stop — feeds the "usually crowded" heuristic.
  Future<Map<int, int>> hourlyDensity(
      String operatorId, String stopId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT (departure_seconds / 3600) % 24 AS hour, COUNT(*) AS n
      FROM stop_times
      WHERE operator_id = ? AND stop_id = ?
      GROUP BY hour
    ''', [operatorId, stopId]);
    return {
      for (final r in rows)
        (r['hour'] as num).toInt(): (r['n'] as num).toInt(),
    };
  }

  Future<void> clear() async {
    final db = await database;
    for (final table in ['stops', 'routes', 'trips', 'stop_times', 'feed_meta']) {
      await db.delete(table);
    }
  }
}
