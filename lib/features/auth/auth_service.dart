import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';

/// MODULE 4 — user profiles.
///
/// Wraps Supabase Auth (email **or** phone) plus the `profiles` table.
class AuthService extends ChangeNotifier {
  AuthService() {
    _client.auth.onAuthStateChange.listen((state) {
      _session = state.session;

      if (state.event == AuthChangeEvent.passwordRecovery &&
          state.session != null) {
        _isPasswordRecovery = true;
        notifyListeners();
        return;
      }

      if (_session == null || state.event == AuthChangeEvent.signedOut) {
        _isPasswordRecovery = false;
        _profile = null;
        _favourites = const [];
        notifyListeners();
        return;
      }

      notifyListeners();
      _refreshUserDataSafely();
    });

    _session = _client.auth.currentSession;

    if (_session != null) {
      _refreshUserDataSafely();
    }
  }

  Future<void> _refreshUserDataSafely() async {
    try {
      await refreshProfile();
    } catch (_) {}

    try {
      await refreshFavourites();
    } catch (_) {}
  }

  final SupabaseClient _client = Supabase.instance.client;

  Session? _session;
  UserProfile? _profile;
  List<FavouriteStop> _favourites = const [];
  bool _isPasswordRecovery = false;

  bool get isSignedIn => _session != null;

  bool get isPasswordRecovery => _isPasswordRecovery;

  User? get user => _session?.user;

  UserProfile? get profile => _profile;

  List<FavouriteStop> get favourites =>
      List.unmodifiable(_favourites);

  /// True when the identifier looks like a Malaysian/international phone
  /// number rather than an email address.
  static bool isPhone(String identifier) =>
      !identifier.contains('@') &&
          RegExp(r'^\+?[0-9 \-]{7,15}$').hasMatch(identifier);

  static String normalisePhone(String raw) {
    final value = raw.replaceAll(RegExp(r'[\s\-]'), '');

    if (value.startsWith('+')) {
      return value;
    }

    if (value.startsWith('0')) {
      return '+60${value.substring(1)}';
    }

    if (value.startsWith('60')) {
      return '+$value';
    }

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
        data: {
          'full_name': fullName,
          'phone': normalisePhone(identifier),
        },
      );
    } else {
      await _client.auth.signUp(
        email: identifier.trim(),
        password: password,
        data: {
          'full_name': fullName,
        },
        emailRedirectTo: AppConfig.emailVerificationRedirect,
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

  Future<void> signOut() async {
    await _client.auth.signOut();

    _session = null;
    _profile = null;
    _favourites = const [];

    notifyListeners();
  }

  // -------------------------------------------------------- forgot password

  Future<void> sendPasswordReset(String identifier) async {
    if (isPhone(identifier)) {
      await _client.auth.signInWithOtp(
        phone: normalisePhone(identifier),
      );
    } else {
      await _client.auth.resetPasswordForEmail(
        identifier.trim(),
        redirectTo: AppConfig.passwordResetRedirect,
      );
    }
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(
        password: newPassword,
      ),
    );
  }

  /// Completes an email password-recovery session and returns the app to the
  /// signed-out state. The user must then sign in with the new password.
  Future<void> completePasswordRecovery(String newPassword) async {
    await updatePassword(newPassword);
    _isPasswordRecovery = false;
    await signOut();
  }

  // --------------------------------------------------------------- profile

  Future<void> refreshProfile() async {
    final id = user?.id;

    if (id == null) {
      return;
    }

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

    if (id == null) {
      return;
    }

    final payload = <String, dynamic>{
      'id': id,
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (homeCity != null) 'home_city': homeCity,
      if (preferredOperator != null)
        'preferred_operator': preferredOperator,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };

    final data = await _client
        .from('profiles')
        .upsert(payload)
        .select()
        .single();

    _profile = UserProfile.fromMap(data);

    notifyListeners();
  }

  // ------------------------------------------------------- favourite stops

  Future<void> refreshFavourites() async {
    final id = user?.id;

    if (id == null) {
      _favourites = const [];
      notifyListeners();
      return;
    }

    final rows = await _client
        .from('favourite_stops')
        .select()
        .eq('user_id', id)
        .order('created_at');

    _favourites = (rows as List)
        .map(
          (row) => FavouriteStop.fromMap(
        row as Map<String, dynamic>,
      ),
    )
        .toList();

    notifyListeners();
  }

  Future<List<FavouriteStop>> favouriteStops() async {
    final id = user?.id;

    if (id == null) {
      return const [];
    }

    final rows = await _client
        .from('favourite_stops')
        .select()
        .eq('user_id', id)
        .order('created_at');

    return (rows as List)
        .map(
          (row) => FavouriteStop.fromMap(
        row as Map<String, dynamic>,
      ),
    )
        .toList();
  }

  bool isFavourite(String stopId) {
    return _favourites.any(
          (favourite) => favourite.stopId == stopId,
    );
  }

  Future<void> addFavourite({
    required String stopId,
    required String stopName,
    required String operatorId,
  }) async {
    final id = user?.id;

    if (id == null) {
      return;
    }

    await _client.from('favourite_stops').upsert(
      {
        'user_id': id,
        'stop_id': stopId,
        'stop_name': stopName,
        'operator': operatorId,
      },
      onConflict: 'user_id,stop_id',
    );

    final newFavourite = FavouriteStop(
      stopId: stopId,
      stopName: stopName,
      operatorId: operatorId,
    );

    final existingIndex = _favourites.indexWhere(
          (favourite) => favourite.stopId == stopId,
    );

    if (existingIndex == -1) {
      _favourites = [
        ..._favourites,
        newFavourite,
      ];
    } else {
      final updated = [..._favourites];
      updated[existingIndex] = newFavourite;
      _favourites = updated;
    }

    notifyListeners();
  }

  Future<void> removeFavourite(String stopId) async {
    final id = user?.id;

    if (id == null) {
      return;
    }

    await _client
        .from('favourite_stops')
        .delete()
        .eq('user_id', id)
        .eq('stop_id', stopId);

    _favourites = _favourites
        .where(
          (favourite) => favourite.stopId != stopId,
    )
        .toList();

    notifyListeners();
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
      (fullName?.trim().isNotEmpty ?? false)
          ? fullName!.trim()
          : 'Commuter';

  factory UserProfile.fromMap(
      Map<String, dynamic> map,
      ) {
    return UserProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      homeCity: map['home_city'] as String?,
      preferredOperator:
      map['preferred_operator'] as String?,
    );
  }
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

  factory FavouriteStop.fromMap(
      Map<String, dynamic> map,
      ) {
    return FavouriteStop(
      stopId: map['stop_id'] as String,
      stopName: map['stop_name'] as String,
      operatorId:
      (map['operator'] as String?) ??
          'rapid-rail-kl',
    );
  }
}