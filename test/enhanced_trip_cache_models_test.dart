import 'package:flutter_test/flutter_test.dart';
import 'package:xploremy/data/models.dart';

void main() {
  test('cache stats expose cached state and counts', () {
    final stats = GtfsCacheStats(
      operatorId: 'rapid-kl',
      lastSync: DateTime(2026, 9, 16, 8),
      stopCount: 120,
      routeCount: 12,
      tripCount: 840,
    );

    expect(stats.isCached, isTrue);
    expect(stats.stopCount, 120);
    expect(stats.tripCount, 840);
  });

  test('trip timetable entry keeps GTFS stop sequence and scheduled time', () {
    const stop = GtfsStop(
      operatorId: 'rapid-kl',
      stopId: 'KLS',
      name: 'KL Sentral',
      lat: 3.1343,
      lon: 101.6861,
    );
    final entry = TripTimetableEntry(
      stop: stop,
      sequence: 5,
      departureSeconds: 7 * 3600 + 30 * 60,
      scheduledAt: DateTime(2026, 9, 16, 7, 30),
    );

    expect(entry.sequence, 5);
    expect(entry.stop.stopId, 'KLS');
    expect(entry.scheduledAt.hour, 7);
    expect(entry.scheduledAt.minute, 30);
  });
}
