import 'package:flutter_test/flutter_test.dart';
import 'package:xploremy/data/models.dart';

void main() {
  test('departure reliability uses live delay thresholds', () {
    final now = DateTime(2026, 9, 15, 8);
    Departure build(int? delay) => Departure(
      operatorId: 'op', tripId: 't', routeLabel: 'R', routeLongName: 'Route', headsign: 'Town',
      scheduledSeconds: 8 * 3600, scheduledAt: now, secondsUntil: 0, routeType: 3, liveDelaySeconds: delay,
    );

    expect(build(null).reliability, Reliability.scheduled);
    expect(build(60).reliability, Reliability.onTime);
    expect(build(180).reliability, Reliability.delayed);
    expect(build(-180).reliability, Reliability.early);
  });

  test('service span preserves first and last timestamps', () {
    final first = DateTime(2026, 9, 15, 6);
    final last = DateTime(2026, 9, 15, 23, 30);
    final span = ServiceSpan(firstAt: first, lastAt: last);
    expect(span.firstAt, first);
    expect(span.lastAt, last);
  });
}
