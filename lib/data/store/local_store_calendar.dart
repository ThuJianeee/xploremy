part of '../local_store.dart';

extension LocalGtfsCalendarStore on LocalGtfsStore {
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

}
