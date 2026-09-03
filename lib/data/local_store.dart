import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/geo.dart';
import 'gtfs_api.dart';
import 'models.dart';

part 'store/local_store_feed.dart';
part 'store/local_store_stops.dart';
part 'store/local_store_planner.dart';
part 'store/local_store_calendar.dart';
part 'store/local_store_departures.dart';
part 'store/local_store_journey.dart';
part 'store/local_store_cache.dart';

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
      version: 3,
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

        if (oldVersion < 3) {
          await _createV3Indexes(db);
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
    await _createV3Indexes(db);
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

  Future<void> _createV3Indexes(Database db) async {
    final batch = db.batch();

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_stops_name ON stops(name COLLATE NOCASE)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_trips_route ON trips(operator_id, route_id, trip_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_stop_times_route_lookup ON stop_times(operator_id, stop_id, trip_id, sequence)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_stop_times_trip_stop ON stop_times(operator_id, trip_id, stop_id, sequence)',
    );

    await batch.commit(noResult: true);
  }

  // ==============================================================
  // FEED META
  // ==============================================================

}
