import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';

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

      if (state.event == AuthChangeEvent.signedOut || state.session == null) {
        _isPasswordRecovery = false;
        _session = null;
        _profile = null;
        _favourites = const [];

        notifyListeners();
        return;
      }

      if (_isPasswordRecovery) {
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

  final SupabaseClient _client = Supabase.instance.client;

  Session? _session;
  UserProfile? _profile;
  List<FavouriteStop> _favourites = const [];
  bool _isPasswordRecovery = false;

  bool get isSignedIn => _session != null;

  bool get isPasswordRecovery => _isPasswordRecovery;

  User? get user => _session?.user;

  UserProfile? get profile => _profile;

  List<FavouriteStop> get favourites {
    return List.unmodifiable(_favourites);
  }

  Future<void> _refreshUserDataSafely() async {
    try {
      await refreshProfile();
    } catch (_) {}

    try {
      await refreshFavourites();
    } catch (_) {}
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await _client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {
        'full_name': fullName.trim(),
      },
      emailRedirectTo: AppConfig.emailVerificationRedirect,
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      redirectTo: AppConfig.passwordResetRedirect,
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(
        password: newPassword,
      ),
    );
  }

  Future<void> completePasswordRecovery(
    String newPassword,
  ) async {
    await _client.auth.updateUser(
      UserAttributes(
        password: newPassword,
      ),
    );
  }

  Future<void> finishPasswordRecovery() async {
    await _client.auth.signOut();
  }

  Future<void> refreshProfile() async {
    final id = user?.id;

    if (id == null) {
      return;
    }

    final data =
        await _client.from('profiles').select().eq('id', id).maybeSingle();

    if (data != null) {
      _profile = UserProfile.fromMap(data);
      notifyListeners();
    }
  }

  Future<void> saveProfile({
    String? fullName,
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
      if (fullName != null) 'full_name': fullName.trim(),
      if (homeCity != null) 'home_city': homeCity.trim(),
      if (preferredOperator != null) 'preferred_operator': preferredOperator,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };

    final data =
        await _client.from('profiles').upsert(payload).select().single();

    _profile = UserProfile.fromMap(data);

    notifyListeners();
  }

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

  Future<void> removeFavourite(
    String stopId,
  ) async {
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
    this.avatarUrl,
    this.homeCity,
    this.preferredOperator,
  });

  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? homeCity;
  final String? preferredOperator;

  String get displayName {
    if (fullName?.trim().isNotEmpty ?? false) {
      return fullName!.trim();
    }

    return 'Commuter';
  }

  factory UserProfile.fromMap(
    Map<String, dynamic> map,
  ) {
    return UserProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      homeCity: map['home_city'] as String?,
      preferredOperator: map['preferred_operator'] as String?,
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
      operatorId: (map['operator'] as String?) ?? 'rapid-rail-kl',
    );
  }
}
