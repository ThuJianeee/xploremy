part of '../local_store.dart';

extension LocalGtfsStopStore on LocalGtfsStore {
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

}
