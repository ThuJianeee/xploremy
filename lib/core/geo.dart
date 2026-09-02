import 'dart:math' as math;

/// Great-circle distance in metres between two WGS84 points.
double haversineMetres(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double deg) => deg * math.pi / 180.0;

String formatDistance(double metres) {
  if (metres < 1000) return '${metres.round()} m';
  return '${(metres / 1000).toStringAsFixed(1)} km';
}

/// "HH:MM:SS" (GTFS allows hours >= 24) -> seconds after service-day midnight.
int? parseGtfsTime(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 3) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final s = int.tryParse(parts[2]);
  if (h == null || m == null || s == null || m > 59 || s > 59 || h < 0) {
    return null;
  }
  return h * 3600 + m * 60 + s;
}

String formatSecondsOfDay(int seconds) {
  final normalised = seconds % 86400;
  final h = normalised ~/ 3600;
  final m = (normalised % 3600) ~/ 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

int nowSecondsOfDay() {
  final now = DateTime.now();
  return now.hour * 3600 + now.minute * 60 + now.second;
}

String formatCountdown(int seconds) {
  if (seconds <= 30) return 'Now';
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String formatClockTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// Clearly labels next-day departures instead of silently wrapping a past
/// schedule by +24 hours.
String formatDepartureTime(DateTime scheduledAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final day = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
  final difference = day.difference(today).inDays;
  final clock = formatClockTime(scheduledAt);
  if (difference == 0) return clock;
  if (difference == 1) return 'Tomorrow $clock';
  if (difference == -1) return 'Yesterday $clock';
  return '${scheduledAt.day}/${scheduledAt.month} $clock';
}
