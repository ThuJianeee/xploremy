/// Central configuration for XploreMY.
class AppConfig {
  static const String supabaseUrl =
      'https://nzjsmetjjyowxhkojoxr.supabase.co';

  static const String supabaseAnonKey =
      'sb_publishable_jBeLV5DJjE-2Or69A3G88A_UaFLHvL5';

  static const String emailVerificationRedirect =
      'xploremy://login-callback';

  static const String passwordResetRedirect =
      'xploremy://reset-password';

  /// Malaysia's official public transport GTFS API.
  static const String dataGovBase =
      'https://api.data.gov.my';

  /// The official docs recommend refreshing static feeds daily before service.
  static const Duration staticFeedTtl =
  Duration(days: 1);

  static const double nearbyRadiusMetres = 1500;
}

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
  final String staticPath;
  final String? realtimePath;

  Uri get staticUrl =>
      Uri.parse(
        '${AppConfig.dataGovBase}$staticPath',
      );

  Uri? get realtimeUrl =>
      realtimePath == null
          ? null
          : Uri.parse(
        '${AppConfig.dataGovBase}$realtimePath',
      );

  bool get hasRealtime =>
      realtimePath != null;

  bool get isRail =>
      id == 'ktmb' ||
          id == 'rapid-rail-kl';
}

/// Operators currently documented by data.gov.my GTFS APIs.
class Operators {
  static const ktmb = Operator(
    id: 'ktmb',
    name: 'KTM Berhad (Komuter & Intercity)',
    shortName: 'KTMB',
    staticPath: '/gtfs-static/ktmb',
    realtimePath:
    '/gtfs-realtime/vehicle-position/ktmb',
  );

  static const rapidRailKl = Operator(
    id: 'rapid-rail-kl',
    name:
    'Prasarana Rapid Rail KL (LRT/MRT/Monorail)',
    shortName: 'Rapid Rail KL',
    staticPath:
    '/gtfs-static/prasarana?category=rapid-rail-kl',
  );

  static const rapidBusKl = Operator(
    id: 'rapid-bus-kl',
    name: 'Prasarana Rapid Bus KL',
    shortName: 'Rapid Bus KL',
    staticPath:
    '/gtfs-static/prasarana?category=rapid-bus-kl',
    realtimePath:
    '/gtfs-realtime/vehicle-position/prasarana?category=rapid-bus-kl',
  );

  static const rapidBusMrtFeeder = Operator(
    id: 'rapid-bus-mrtfeeder',
    name: 'Prasarana MRT Feeder Bus',
    shortName: 'MRT Feeder',
    staticPath:
    '/gtfs-static/prasarana?category=rapid-bus-mrtfeeder',
    realtimePath:
    '/gtfs-realtime/vehicle-position/prasarana?category=rapid-bus-mrtfeeder',
  );

  static const rapidBusPenang = Operator(
    id: 'rapid-bus-penang',
    name: 'Prasarana Rapid Bus Penang',
    shortName: 'Rapid Penang',
    staticPath:
    '/gtfs-static/prasarana?category=rapid-bus-penang',
    realtimePath:
    '/gtfs-realtime/vehicle-position/prasarana?category=rapid-bus-penang',
  );

  static const rapidBusKuantan = Operator(
    id: 'rapid-bus-kuantan',
    name: 'Prasarana Rapid Bus Kuantan',
    shortName: 'Rapid Kuantan',
    staticPath:
    '/gtfs-static/prasarana?category=rapid-bus-kuantan',
    realtimePath:
    '/gtfs-realtime/vehicle-position/prasarana?category=rapid-bus-kuantan',
  );

  static const myBasKangar = Operator(
    id: 'mybas-kangar',
    name: 'BAS.MY Kangar',
    shortName: 'BAS.MY Kangar',
    staticPath:
    '/gtfs-static/mybas-kangar',
    realtimePath:
    '/gtfs-realtime/vehicle-position/mybas-kangar',
  );

  static const myBasAlorSetar = Operator(
    id: 'mybas-alor-setar',
    name: 'BAS.MY Alor Setar',
    shortName: 'BAS.MY Alor Setar',
    staticPath:
    '/gtfs-static/mybas-alor-setar',
    realtimePath:
    '/gtfs-realtime/vehicle-position/mybas-alor-setar',
  );

  static const myBasKotaBharu = Operator(
    id: 'mybas-kota-bharu',
    name: 'BAS.MY Kota Bharu',
    shortName: 'BAS.MY Kota Bharu',
    staticPath:
    '/gtfs-static/mybas-kota-bharu',
    realtimePath:
    '/gtfs-realtime/vehicle-position/mybas-kota-bharu',
  );

  static const myBasTerengganu = Operator(
    id: 'mybas-kuala-terengganu',
    name: 'BAS.MY Kuala Terengganu',
    shortName: 'BAS.MY Terengganu',
    staticPath:
    '/gtfs-static/mybas-kuala-terengganu',
    realtimePath:
    '/gtfs-realtime/vehicle-position/mybas-kuala-terengganu',
  );

  static const myBasIpoh = Operator(
    id: 'mybas-ipoh',
    name: 'BAS.MY Ipoh',
    shortName: 'BAS.MY Ipoh',
    staticPath:
    '/gtfs-static/mybas-ipoh',
    realtimePath:
    '/gtfs-realtime/vehicle-position/mybas-ipoh',
  );

  static const myBasSerembanA = Operator(
    id: 'mybas-seremban-a',
    name: 'BAS.MY Seremban (Operator A)',
    shortName: 'BAS.MY Seremban A',
    staticPath:
    '/gtfs-static/mybas-seremban-a',
    realtimePath:
    '/gtfs-realtime/vehicle-position/mybas-seremban-a',
  );

  static const myBasSerembanB = Operator(
    id: 'mybas-seremban-b',
    name: 'BAS.MY Seremban (Operator B)',
    shortName: 'BAS.MY Seremban B',
    staticPath:
    '/gtfs-static/mybas-seremban-b',
    realtimePath:
    '/gtfs-realtime/vehicle-position/mybas-seremban-b',
  );

  static const myBasMelaka = Operator(
    id: 'mybas-melaka',
    name: 'BAS.MY Melaka',
    shortName: 'BAS.MY Melaka',
    staticPath:
    '/gtfs-static/mybas-melaka',
    realtimePath:
    '/gtfs-realtime/vehicle-position/mybas-melaka',
  );

  static const myBasJohor = Operator(
    id: 'mybas-johor',
    name: 'BAS.MY Johor Bahru',
    shortName: 'BAS.MY Johor',
    staticPath:
    '/gtfs-static/mybas-johor',
    realtimePath:
    '/gtfs-realtime/vehicle-position/mybas-johor',
  );

  static const myBasKuching = Operator(
    id: 'mybas-kuching',
    name: 'BAS.MY Kuching',
    shortName: 'BAS.MY Kuching',
    staticPath:
    '/gtfs-static/mybas-kuching',
    realtimePath:
    '/gtfs-realtime/vehicle-position/mybas-kuching',
  );

  static const all = <Operator>[
    ktmb,
    rapidRailKl,
    rapidBusKl,
    rapidBusMrtFeeder,
    rapidBusPenang,
    rapidBusKuantan,
    myBasKangar,
    myBasAlorSetar,
    myBasKotaBharu,
    myBasTerengganu,
    myBasIpoh,
    myBasSerembanA,
    myBasSerembanB,
    myBasMelaka,
    myBasJohor,
    myBasKuching,
  ];

  static Operator byId(
      String id,
      ) {
    return all.firstWhere(
          (operator) =>
      operator.id == id,
      orElse: () =>
      rapidRailKl,
    );
  }
}