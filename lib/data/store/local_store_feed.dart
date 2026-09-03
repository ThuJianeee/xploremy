part of '../local_store.dart';

extension LocalGtfsFeedStore on LocalGtfsStore {
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

}
