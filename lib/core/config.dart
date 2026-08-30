/// Central configuration for XploreMY.
///
/// These are publishable Supabase client credentials. They are expected to be
/// present in a mobile binary; Row Level Security protects user data.
class AppConfig {
  static const String supabaseUrl = 'https://guwgewycvbnpbyzykfje.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_kH3jIApQzPokCOog_OhsTw_bn9SFbEx';

  /// Deep link used for password-reset emails.
  /// Register this scheme in AndroidManifest.xml / Info.plist.
  static const String passwordResetRedirect = 'xploremy://reset-password';

  /// MAMPU DTSA open data base URL. No API key required.
  static const String dataGovBase = 'https://api.data.gov.my';

  /// How long a cached GTFS-static feed stays fresh before we refetch.
  static const Duration staticFeedTtl = Duration(days: 3);

  /// Radius used by the "nearby stops" search.
  static const double nearbyRadiusMetres = 1500;
}

/// A transit operator published on the DTSA open data platform.
class Operator {
  const Operator({
    required this.id,
    required this.name,
    required this.shortName,
    required this.staticPath,
    this.realtimePath,
  });

  final String id;
  final String name;
  final String shortName;

  /// Path to the GTFS-static ZIP feed.
  final String staticPath;

  /// Path to the GTFS-realtime vehicle-position feed (protobuf), if published.
  final String? realtimePath;

  Uri get staticUrl => Uri.parse('${AppConfig.dataGovBase}$staticPath');
  Uri? get realtimeUrl => realtimePath == null
      ? null
      : Uri.parse('${AppConfig.dataGovBase}$realtimePath');

  bool get hasRealtime => realtimePath != null;
}

/// The three operator families named in the brief: KTMB, Prasarana and BAS.MY.
class Operators {
  static const ktmb = Operator(
    id: 'ktmb',
    name: 'KTM Berhad (Komuter & Intercity)',
    shortName: 'KTMB',
    staticPath: '/gtfs-static/ktmb',
    realtimePath: '/gtfs-realtime/vehicle-position/ktmb',
  );

  static const rapidRailKl = Operator(
    id: 'rapid-rail-kl',
    name: 'Prasarana Rapid Rail KL (LRT/MRT/Monorail)',
    shortName: 'Rapid Rail KL',
    staticPath: '/gtfs-static/prasarana?category=rapid-rail-kl',
  );

  static const rapidBusKl = Operator(
    id: 'rapid-bus-kl',
    name: 'Prasarana Rapid Bus KL',
    shortName: 'Rapid Bus KL',
    staticPath: '/gtfs-static/prasarana?category=rapid-bus-kl',
    realtimePath: '/gtfs-realtime/vehicle-position/prasarana?category=rapid-bus-kl',
  );

  static const rapidBusPenang = Operator(
    id: 'rapid-bus-penang',
    name: 'Prasarana Rapid Bus Penang',
    shortName: 'Rapid Penang',
    staticPath: '/gtfs-static/prasarana?category=rapid-bus-penang',
    realtimePath:
        '/gtfs-realtime/vehicle-position/prasarana?category=rapid-bus-penang',
  );

  static const rapidBusMrtFeeder = Operator(
    id: 'rapid-bus-mrtfeeder',
    name: 'Prasarana MRT Feeder Bus',
    shortName: 'MRT Feeder',
    staticPath: '/gtfs-static/prasarana?category=rapid-bus-mrtfeeder',
    realtimePath:
        '/gtfs-realtime/vehicle-position/prasarana?category=rapid-bus-mrtfeeder',
  );

  static const myBasJohor = Operator(
    id: 'mybas-johor',
    name: 'BAS.MY Johor (myBAS)',
    shortName: 'BAS.MY Johor',
    staticPath: '/gtfs-static/mybas-johor',
    realtimePath: '/gtfs-realtime/vehicle-position/mybas-johor',
  );

  static const all = <Operator>[
    ktmb,
    rapidRailKl,
    rapidBusKl,
    rapidBusMrtFeeder,
    rapidBusPenang,
    myBasJohor,
  ];

  static Operator byId(String id) =>
      all.firstWhere((o) => o.id == id, orElse: () => rapidRailKl);
}
