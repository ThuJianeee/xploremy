import 'package:flutter_test/flutter_test.dart';
import 'package:xploremy/core/geo.dart';

void main() {
  group('GTFS time parsing', () {
    test('parses HH:MM:SS', () {
      expect(parseGtfsTime('07:30:00'), 7 * 3600 + 30 * 60);
    });

    test('supports hours past midnight (GTFS allows >= 24)', () {
      expect(parseGtfsTime('25:15:00'), 25 * 3600 + 15 * 60);
    });

    test('rejects malformed values', () {
      expect(parseGtfsTime('not-a-time'), isNull);
      expect(parseGtfsTime('07:30'), isNull);
    });
  });

  group('formatting', () {
    test('wraps seconds-of-day past midnight', () {
      expect(formatSecondsOfDay(25 * 3600 + 15 * 60), '01:15');
    });

    test('countdown reads naturally', () {
      expect(formatCountdown(10), 'Now');
      expect(formatCountdown(300), '5 min');
      expect(formatCountdown(3600), '1h');
      expect(formatCountdown(5400), '1h 30m');
    });

    test('distance switches to km', () {
      expect(formatDistance(450), '450 m');
      expect(formatDistance(2350), '2.4 km');
    });
  });

  group('haversine', () {
    test('KL Sentral to KLCC is roughly 3.5 km', () {
      final metres = haversineMetres(3.13430, 101.68610, 3.15920, 101.71310);
      expect(metres, greaterThan(3000));
      expect(metres, lessThan(4500));
    });

    test('zero distance for identical points', () {
      expect(haversineMetres(3.1, 101.7, 3.1, 101.7), closeTo(0, 0.001));
    });
  });
}
