import 'package:geolocator/geolocator.dart';

/// Device location with graceful fallback to KL Sentral so the app is still
/// demonstrable on an emulator with no GPS fix.
class LocationService {
  static const double fallbackLat = 3.13430;
  static const double fallbackLon = 101.68610;
  static const String fallbackLabel = 'KL Sentral (default location)';

  static Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(
          lat: fallbackLat,
          lon: fallbackLon,
          isFallback: true,
          message: 'Location services are off — showing stops around KL Sentral.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationResult(
          lat: fallbackLat,
          lon: fallbackLon,
          isFallback: true,
          message: 'Location permission denied — showing stops around KL Sentral.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationResult(lat: position.latitude, lon: position.longitude);
    } catch (_) {
      return const LocationResult(
        lat: fallbackLat,
        lon: fallbackLon,
        isFallback: true,
        message: 'Couldn\u2019t get a GPS fix — showing stops around KL Sentral.',
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
