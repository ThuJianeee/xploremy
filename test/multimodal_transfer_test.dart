import 'package:flutter_test/flutter_test.dart';
import 'package:xploremy/core/transit_mode.dart';

void main() {
  test('bus and rail routes get a practical interchange walking radius', () {
    expect(isBusRailPair(3, 1), isTrue);
    expect(isBusRailPair(1, 3), isTrue);
    expect(
      transferWalkingRadiusMetres(
        firstRouteType: 3,
        secondRouteType: 1,
        sameStationName: false,
        knownWalkingInterchange: false,
      ),
      600,
    );
  });

  test('ordinary unrelated transfer remains conservative', () {
    expect(
      transferWalkingRadiusMetres(
        firstRouteType: 3,
        secondRouteType: 3,
        sameStationName: false,
        knownWalkingInterchange: false,
      ),
      350,
    );
  });
}
