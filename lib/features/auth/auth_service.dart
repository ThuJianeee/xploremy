import 'dart:async';

import 'package:app_links/app_links.dart';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';

bool isPasswordResetDeepLink(Uri? uri) {
  if (uri == null) return false;
  return uri.scheme.toLowerCase() == 'xploremy' &&
      uri.host.toLowerCase() == 'reset-password';
}

class AuthService extends ChangeNotifier {
  AuthService() {
    _session = _client.auth.currentSession;
    _listenForAuthChanges();
    _listenForRecoveryLinks();

    if (_session != null) {
      _refreshUserDataSafely();
    }
  }

  final SupabaseClient _client = Supabase.instance.client;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<Uri>? _linkSubscription;
  bool _deferAccountDeletionNotification = false;

  void _listenForAuthChanges() {
    _authSubscription = _client.auth.onAuthStateChange.listen((state) {
      _session = state.session;

      if (_deferAccountDeletionNotification) {
        if (state.event == AuthChangeEvent.signedOut || state.session == null) {
          _session = null;
          _profile = null;
          _favourites = const [];
          _isPasswordRecovery = false;
        }
        return;
      }

      if (state.event == AuthChangeEvent.passwordRecovery &&
          state.session != null) {
        _isPasswordRecovery = true;
        notifyListeners();
        return;
      }

      if (state.event == AuthChangeEvent.signedOut) {
        _isPasswordRecovery = false;
        _session = null;
        _profile = null;
        _favourites = const [];
        notifyListeners();
        return;
      }

      if (state.session == null) {
        if (!_isPasswordRecovery) {
          _session = null;
          _profile = null;
          _favourites = const [];
        }
        notifyListeners();
        return;
      }

      if (_isPasswordRecovery) {
        notifyListeners();
        return;
      }

      notifyListeners();
      _refreshUserDataSafely();
    });
  }

  void _listenForRecoveryLinks() {
    _appLinks.getInitialLink().then(_handleIncomingLink).catchError((_) {});
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (_) {},
    );
  }

  void _handleIncomingLink(Uri? uri) {
    if (uri == null) return;
    if (isPasswordResetDeepLink(uri)) {
      _isPasswordRecovery = true;
      _session = _client.auth.currentSession ?? _session;
      notifyListeners();
    }
  }

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
    final response = await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final userId = response.user?.id;
    if (userId == null) return;
    final profile =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (profile?['is_suspended'] == true) {
      await _client.auth.signOut();
      throw StateError('This account has been suspended by an administrator.');
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> deleteAccount({bool deferUiNotification = false}) async {
    final id = user?.id;
    if (id == null) {
      throw StateError('Sign in required');
    }

    _deferAccountDeletionNotification = deferUiNotification;

    try {
      try {
        await _client.storage.from('avatars').remove(['$id/avatar']);
      } catch (_) {}

      await _client.rpc('delete_my_account');

      try {
        await _client.auth.signOut();
      } catch (_) {}

      _session = null;
      _profile = null;
      _favourites = const [];
      _isPasswordRecovery = false;

      if (!deferUiNotification) {
        _deferAccountDeletionNotification = false;
        notifyListeners();
      }
    } catch (_) {
      _deferAccountDeletionNotification = false;
      rethrow;
    }
  }

  void finishDeferredAccountDeletion() {
    if (!_deferAccountDeletionNotification) return;
    _deferAccountDeletionNotification = false;
    notifyListeners();
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
    _isPasswordRecovery = false;
    _session = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> refreshProfile() async {
    final id = user?.id;

    if (id == null) {
      return;
    }

    final data =
        await _client.from('profiles').select().eq('id', id).maybeSingle();

    if (data != null) {
      final profile = UserProfile.fromMap(data);
      if (profile.isSuspended) {
        await _client.auth.signOut();
        _session = null;
        _profile = null;
        _favourites = const [];
        notifyListeners();
        return;
      }
      _profile = profile;
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

  Future<String> uploadAvatarBytes({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final id = user?.id;
    if (id == null) throw StateError('Sign in required');

    const pathName = 'avatar';
    final path = '$id/$pathName';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
            cacheControl: '3600',
          ),
        );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
    final cacheBusted = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    final data = await _client
        .from('profiles')
        .upsert({'id': id, 'avatar_url': cacheBusted})
        .select()
        .single();
    _profile = UserProfile.fromMap(data);
    notifyListeners();
    return cacheBusted;
  }

  Future<void> removeAvatar() async {
    final id = user?.id;
    if (id == null) return;

    try {
      await _client.storage.from('avatars').remove(['$id/avatar']);
    } catch (_) {}

    final data = await _client
        .from('profiles')
        .upsert({'id': id, 'avatar_url': null})
        .select()
        .single();
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
    this.role = 'user',
    this.isSuspended = false,
  });

  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? homeCity;
  final String? preferredOperator;
  final String role;
  final bool isSuspended;

  bool get isAdmin => role.toLowerCase() == 'admin';

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
      role: (map['role'] as String?) ?? 'user',
      isSuspended: map['is_suspended'] as bool? ?? false,
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
