part of '../local_store.dart';

extension LocalGtfsCacheStore on LocalGtfsStore {
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
