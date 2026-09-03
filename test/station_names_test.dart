import 'package:flutter_test/flutter_test.dart';
import 'package:xploremy/core/station_names.dart';

void main() {
  test('removes REDONE suffix from GTFS station names', () {
    expect(cleanStationName('KL SENTRAL - REDONE'), 'KL SENTRAL');
    expect(cleanStationName('KL SENTRAL-redone'), 'KL SENTRAL');
  });

  test('normalises repeated spaces', () {
    expect(cleanStationName('  Bukit   Bintang  '), 'Bukit Bintang');
  });
}
