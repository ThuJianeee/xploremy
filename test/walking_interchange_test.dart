import 'package:flutter_test/flutter_test.dart';
import 'package:xploremy/core/station_names.dart';

void main() {
  group('known walking interchanges', () {
    test('connects KL Sentral and Muzium Negara', () {
      expect(
        areKnownWalkingInterchangeNames(
            'KL Sentral', 'Muzium Negara MRT Station'),
        isTrue,
      );
      expect(
        areKnownWalkingInterchangeNames('Muzium Negara', 'KL Sentral'),
        isTrue,
      );
    });

    test('does not treat unrelated stations as linked', () {
      expect(
        areKnownWalkingInterchangeNames('KL Sentral', 'TTDI'),
        isFalse,
      );
    });
  });
}
