import '../core/config.dart';
import 'gtfs_api.dart';
import 'models.dart';

/// A tiny hand-written feed (a slice of the Kelana Jaya LRT line plus a feeder
/// bus) used for offline demos, widget tests, and UI work before the live
/// DTSA feeds are wired in.
List<GtfsStaticFeed> buildMockFeeds() {
  final now = DateTime.now();

  const railStops = <(String, String, double, double)>[
    ('KJ13', 'KLCC', 3.15920, 101.71310),
    ('KJ14', 'Kampung Baru', 3.16260, 101.70560),
    ('KJ15', 'Dang Wangi', 3.15690, 101.70170),
    ('KJ16', 'Masjid Jamek', 3.14930, 101.69660),
    ('KJ17', 'Pasar Seni', 3.14250, 101.69540),
    ('KJ18', 'KL Sentral', 3.13430, 101.68610),
  ];

  const busStops = <(String, String, double, double)>[
    ('B101', 'Jalan Ampang (KLCC)', 3.15840, 101.71510),
    ('B102', 'Jalan Sultan Ismail', 3.15540, 101.70890),
    ('B103', 'Bukit Bintang', 3.14690, 101.71120),
    ('B104', 'Stadium Merdeka', 3.13930, 101.69880),
  ];

  GtfsStaticFeed build({
    required Operator op,
    required List<(String, String, double, double)> stops,
    required GtfsRoute route,
    required List<int> departureHours,
    required int headwayMinutes,
    required String headsign,
  }) {
    final trips = <GtfsTrip>[];
    final stopTimes = <GtfsStopTime>[];
    var tripIndex = 0;

    for (final hour in departureHours) {
      for (var m = 0; m < 60; m += headwayMinutes) {
        final tripId = '${op.id}-t${tripIndex++}';
        trips.add(GtfsTrip(
          operatorId: op.id,
          tripId: tripId,
          routeId: route.routeId,
          serviceId: 'daily',
          headsign: headsign,
        ));
        var offset = 0;
        for (var i = 0; i < stops.length; i++) {
          stopTimes.add(GtfsStopTime(
            operatorId: op.id,
            tripId: tripId,
            stopId: stops[i].$1,
            departureSeconds: hour * 3600 + m * 60 + offset,
            sequence: i + 1,
          ));
          offset += 180;
        }
      }
    }

    return GtfsStaticFeed(
      operatorId: op.id,
      stops: [
        for (final s in stops)
          GtfsStop(
            operatorId: op.id,
            stopId: s.$1,
            name: s.$2,
            lat: s.$3,
            lon: s.$4,
          ),
      ],
      routes: [route],
      trips: trips,
      stopTimes: stopTimes,
      calendar: [
        GtfsCalendarService(
          operatorId: op.id,
          serviceId: 'daily',
          monday: true,
          tuesday: true,
          wednesday: true,
          thursday: true,
          friday: true,
          saturday: true,
          sunday: true,
          startDate: 20200101,
          endDate: 20991231,
        ),
      ],
      calendarDates: const [],
      frequencies: const [],
      fetchedAt: now,
    );
  }

  return [
    build(
      op: Operators.rapidRailKl,
      stops: railStops,
      route: const GtfsRoute(
        operatorId: 'rapid-rail-kl',
        routeId: 'KJL',
        shortName: 'KJL',
        longName: 'Kelana Jaya Line',
        type: 1,
        colorHex: 'D62839',
      ),
      departureHours: List<int>.generate(19, (i) => i + 5),
      headwayMinutes: 6,
      headsign: 'Gombak',
    ),
    build(
      op: Operators.rapidBusKl,
      stops: busStops,
      route: const GtfsRoute(
        operatorId: 'rapid-bus-kl',
        routeId: '300',
        shortName: '300',
        longName: 'Ampang - Pasar Seni',
        type: 3,
        colorHex: '00857C',
      ),
      departureHours: List<int>.generate(18, (i) => i + 6),
      headwayMinutes: 15,
      headsign: 'Pasar Seni',
    ),
  ];
}
