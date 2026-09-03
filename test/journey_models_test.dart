import 'package:flutter_test/flutter_test.dart';
import 'package:xploremy/data/models.dart';

GtfsStop stop(String id, String name) => GtfsStop(
      operatorId: 'rapid-rail-kl',
      stopId: id,
      name: name,
      lat: 3.0,
      lon: 101.0,
    );

void main() {
  test('direct journey reports zero transfers', () {
    final leg = JourneyLeg(
      fromStop: stop('a', 'A'),
      toStop: stop('b', 'B'),
      operatorId: 'rapid-rail-kl',
      tripId: 'trip-1',
      routeId: 'KJL',
      routeLabel: 'Kelana Jaya',
      routeLongName: 'LRT Kelana Jaya Line',
      headsign: 'Gombak',
      departureAt: DateTime(2026, 9, 3, 10),
      arrivalAt: DateTime(2026, 9, 3, 10, 15),
      stopCount: 5,
      routeType: 1,
    );

    final journey = JourneyPlan(legs: [leg]);
    expect(journey.isDirect, isTrue);
    expect(journey.transferCount, 0);
    expect(journey.duration, const Duration(minutes: 15));
  });

  test('walking transfer is included in total duration', () {
    final leg = JourneyLeg(
      fromStop: stop('a', 'A'),
      toStop: stop('b', 'B'),
      operatorId: 'rapid-rail-kl',
      tripId: 'trip-1',
      routeId: 'KJL',
      routeLabel: 'Kelana Jaya',
      routeLongName: 'LRT Kelana Jaya Line',
      headsign: 'Gombak',
      departureAt: DateTime(2026, 9, 3, 10, 5),
      arrivalAt: DateTime(2026, 9, 3, 10, 20),
      stopCount: 5,
      routeType: 1,
    );
    final transfer = JourneyTransfer(
      fromStop: stop('x', 'X'),
      toStop: stop('a', 'A'),
      distanceMetres: 250,
      walkSeconds: 300,
    );

    final journey = JourneyPlan(
      legs: [leg],
      beforeFirstLeg: transfer,
    );

    expect(journey.transferCount, 1);
    expect(journey.duration, const Duration(minutes: 20));
  });
}
