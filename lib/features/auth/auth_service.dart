import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';

/// MODULE 4 — user profiles.
///
/// Wraps Supabase Auth (email **or** phone) plus the `profiles` table.
class AuthService extends ChangeNotifier {
  AuthService() {
    _client.auth.onAuthStateChange.listen((event) {
      _session = event.session;
      if (_session == null) _profile = null;
      notifyListeners();
      if (_session != null) refreshProfile();
    });
    _session = _client.auth.currentSession;
    if (_session != null) refreshProfile();
  }

  final SupabaseClient _client = Supabase.instance.client;

  Session? _session;
  UserProfile? _profile;

  bool get isSignedIn => _session != null;
  User? get user => _session?.user;
  UserProfile? get profile => _profile;

  /// True when the identifier looks like a Malaysian/international phone
  /// number rather than an email address.
  static bool isPhone(String identifier) =>
      !identifier.contains('@') &&
      RegExp(r'^\+?[0-9 \-]{7,15}$').hasMatch(identifier);

  static String normalisePhone(String raw) {
    var value = raw.replaceAll(RegExp(r'[\s\-]'), '');
    if (value.startsWith('+')) return value;
    if (value.startsWith('0')) return '+60${value.substring(1)}';
    if (value.startsWith('60')) return '+$value';
    return '+$value';
  }

  // -------------------------------------------------------------- register

  Future<void> register({
    required String identifier,
    required String password,
    required String fullName,
  }) async {
    if (isPhone(identifier)) {
      await _client.auth.signUp(
        phone: normalisePhone(identifier),
        password: password,
        data: {'full_name': fullName, 'phone': normalisePhone(identifier)},
      );
    } else {
      await _client.auth.signUp(
        email: identifier.trim(),
        password: password,
        data: {'full_name': fullName},
        emailRedirectTo: AppConfig.passwordResetRedirect,
      );
    }
  }

  /// SMS registrations must confirm a one-time code.
  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    await _client.auth.verifyOTP(
      type: OtpType.sms,
      phone: normalisePhone(phone),
      token: token,
    );
  }

  // ------------------------------------------------------------------ login

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    if (isPhone(identifier)) {
      await _client.auth.signInWithPassword(
        phone: normalisePhone(identifier),
        password: password,
      );
    } else {
      await _client.auth.signInWithPassword(
        email: identifier.trim(),
        password: password,
      );
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  // -------------------------------------------------------- forgot password

  Future<void> sendPasswordReset(String identifier) async {
    if (isPhone(identifier)) {
      // Phone accounts recover through a one-time SMS code.
      await _client.auth.signInWithOtp(phone: normalisePhone(identifier));
    } else {
      await _client.auth.resetPasswordForEmail(
        identifier.trim(),
        redirectTo: AppConfig.passwordResetRedirect,
      );
    }
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // --------------------------------------------------------------- profile

  Future<void> refreshProfile() async {
    final id = user?.id;
    if (id == null) return;
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data != null) {
      _profile = UserProfile.fromMap(data);
      notifyListeners();
    }
  }

  Future<void> saveProfile({
    String? fullName,
    String? phone,
    String? homeCity,
    String? preferredOperator,
    String? avatarUrl,
  }) async {
    final id = user?.id;
    if (id == null) return;
    final payload = <String, dynamic>{
      'id': id,
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (homeCity != null) 'home_city': homeCity,
      if (preferredOperator != null) 'preferred_operator': preferredOperator,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
    final data =
        await _client.from('profiles').upsert(payload).select().single();
    _profile = UserProfile.fromMap(data);
    notifyListeners();
  }

  // ------------------------------------------------------- favourite stops

  Future<List<FavouriteStop>> favouriteStops() async {
    final id = user?.id;
    if (id == null) return const [];
    final rows = await _client
        .from('favourite_stops')
        .select()
        .eq('user_id', id)
        .order('created_at');
    return (rows as List).map((r) => FavouriteStop.fromMap(r)).toList();
  }

  Future<void> addFavourite({
    required String stopId,
    required String stopName,
    required String operatorId,
  }) async {
    final id = user?.id;
    if (id == null) return;
    await _client.from('favourite_stops').upsert({
      'user_id': id,
      'stop_id': stopId,
      'stop_name': stopName,
      'operator': operatorId,
    }, onConflict: 'user_id,stop_id');
  }

  Future<void> removeFavourite(String stopId) async {
    final id = user?.id;
    if (id == null) return;
    await _client
        .from('favourite_stops')
        .delete()
        .eq('user_id', id)
        .eq('stop_id', stopId);
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.homeCity,
    this.preferredOperator,
  });

  final String id;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String? homeCity;
  final String? preferredOperator;

  String get displayName =>
      (fullName?.trim().isNotEmpty ?? false) ? fullName!.trim() : 'Commuter';

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        id: m['id'] as String,
        fullName: m['full_name'] as String?,
        phone: m['phone'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        homeCity: m['home_city'] as String?,
        preferredOperator: m['preferred_operator'] as String?,
      );
}

class FavouriteStop {
  const FavouriteStop({
    required this.stopId,
    required this.stopName,
    required this.operatorId,
  });

  final String stopId;
  final String stopName;
  final String operatorId;

  factory FavouriteStop.fromMap(Map<String, dynamic> m) => FavouriteStop(
        stopId: m['stop_id'] as String,
        stopName: m['stop_name'] as String,
        operatorId: (m['operator'] as String?) ?? 'rapid-rail-kl',
      );
}
