import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Device location service.
///
/// Tries to obtain the real device/emulator GPS position first.
/// Falls back to KL Sentral only when location cannot be obtained.
class LocationService {
  static const double fallbackLat = 3.13430;
  static const double fallbackLon = 101.68610;

  static const String fallbackLabel =
      'KL Sentral (default location)';

  static Future<LocationResult> current() async {
    try {
      // ------------------------------------------------------------
      // 1. Check whether device location service is enabled
      // ------------------------------------------------------------

      final serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return const LocationResult(
          lat: fallbackLat,
          lon: fallbackLon,
          isFallback: true,
          message:
          'Location services are off — showing stops around KL Sentral.',
        );
      }

      // ------------------------------------------------------------
      // 2. Check Android location permission
      // ------------------------------------------------------------

      var permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationResult(
          lat: fallbackLat,
          lon: fallbackLon,
          isFallback: true,
          message:
          'Location permission denied — showing stops around KL Sentral.',
        );
      }

      if (permission ==
          LocationPermission.deniedForever) {
        return const LocationResult(
          lat: fallbackLat,
          lon: fallbackLon,
          isFallback: true,
          message:
          'Location permission permanently denied. Enable it in Settings.',
        );
      }

      // ------------------------------------------------------------
      // 3. Try to obtain a fresh GPS position
      // ------------------------------------------------------------

      try {
        final position =
        await Geolocator.getCurrentPosition(
          locationSettings:
          const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );

        debugPrint(
          'GPS current position: '
              '${position.latitude}, '
              '${position.longitude}',
        );

        return LocationResult(
          lat: position.latitude,
          lon: position.longitude,
          isFallback: false,
        );
      } catch (e) {
        debugPrint(
          'getCurrentPosition failed: $e',
        );
      }

      // ------------------------------------------------------------
      // 4. Emulator sometimes has a location but no fresh GPS fix.
      //    Try last known position.
      // ------------------------------------------------------------

      try {
        final lastPosition =
        await Geolocator.getLastKnownPosition();

        if (lastPosition != null) {
          debugPrint(
            'GPS last known position: '
                '${lastPosition.latitude}, '
                '${lastPosition.longitude}',
          );

          return LocationResult(
            lat: lastPosition.latitude,
            lon: lastPosition.longitude,
            isFallback: false,
          );
        }
      } catch (e) {
        debugPrint(
          'getLastKnownPosition failed: $e',
        );
      }

      // ------------------------------------------------------------
      // 5. Nothing available
      // ------------------------------------------------------------

      return const LocationResult(
        lat: fallbackLat,
        lon: fallbackLon,
        isFallback: true,
        message:
        'Couldn’t get a GPS fix — showing stops around KL Sentral.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'LocationService error: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      return const LocationResult(
        lat: fallbackLat,
        lon: fallbackLon,
        isFallback: true,
        message:
        'Couldn’t get a GPS fix — showing stops around KL Sentral.',
      );
    }
  }
}

class LocationResult {
  const LocationResult({
    required this.lat,
    required this.lon,
    this.isFallback = false,
    this.message,
  });

  final double lat;
  final double lon;

  final bool isFallback;

  final String? message;
}