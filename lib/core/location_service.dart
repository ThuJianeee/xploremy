import 'package:geolocator/geolocator.dart';

class LocationService {
  static const double fallbackLat = 3.13430;
  static const double fallbackLon = 101.68610;

  static const String fallbackLabel = 'KL Sentral (default location)';

  static Future<LocationResult> current() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return const LocationResult(
          lat: fallbackLat,
          lon: fallbackLon,
          isFallback: true,
          message:
              'Location services are off — showing stops around KL Sentral.',
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
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

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          lat: fallbackLat,
          lon: fallbackLon,
          isFallback: true,
          message:
              'Location permission permanently denied. Enable it in Settings.',
        );
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );

        return LocationResult(
          lat: position.latitude,
          lon: position.longitude,
          isFallback: false,
        );
      } catch (_) {}

      try {
        final lastPosition = await Geolocator.getLastKnownPosition();

        if (lastPosition != null) {
          return LocationResult(
            lat: lastPosition.latitude,
            lon: lastPosition.longitude,
            isFallback: false,
          );
        }
      } catch (_) {}

      return const LocationResult(
        lat: fallbackLat,
        lon: fallbackLon,
        isFallback: true,
        message: 'Couldn’t get a GPS fix — showing stops around KL Sentral.',
      );
    } catch (_) {
      return const LocationResult(
        lat: fallbackLat,
        lon: fallbackLon,
        isFallback: true,
        message: 'Couldn’t get a GPS fix — showing stops around KL Sentral.',
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
