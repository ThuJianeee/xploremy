import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardStats {
  const AdminDashboardStats({
    required this.totalUsers,
    required this.pendingReviews,
    required this.openReports,
    required this.activeAlerts,
  });

  final int totalUsers;
  final int pendingReviews;
  final int openReports;
  final int activeAlerts;

  factory AdminDashboardStats.fromMap(Map<String, dynamic> map) {
    return AdminDashboardStats(
      totalUsers: (map['total_users'] as num?)?.toInt() ?? 0,
      pendingReviews: (map['pending_reviews'] as num?)?.toInt() ?? 0,
      openReports: (map['open_reports'] as num?)?.toInt() ?? 0,
      activeAlerts: (map['active_alerts'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminUserRecord {
  const AdminUserRecord({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isSuspended,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String role;
  final bool isSuspended;
  final DateTime createdAt;

  bool get isAdmin => role.toLowerCase() == 'admin';

  factory AdminUserRecord.fromMap(Map<String, dynamic> map) {
    return AdminUserRecord(
      id: map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      fullName: map['full_name'] as String? ?? '',
      role: map['role'] as String? ?? 'user',
      isSuspended: map['is_suspended'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AdminServiceAlert {
  const AdminServiceAlert({
    required this.id,
    required this.operatorId,
    required this.title,
    required this.body,
    required this.severity,
    required this.startsAt,
    required this.endsAt,
  });

  final String id;
  final String? operatorId;
  final String title;
  final String body;
  final String severity;
  final DateTime startsAt;
  final DateTime? endsAt;

  bool get isActive {
    final now = DateTime.now();
    return !startsAt.isAfter(now) && (endsAt == null || !endsAt!.isBefore(now));
  }

  factory AdminServiceAlert.fromMap(Map<String, dynamic> map) {
    return AdminServiceAlert(
      id: map['id'] as String? ?? '',
      operatorId: map['operator_id'] as String?,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      severity: map['severity'] as String? ?? 'info',
      startsAt: DateTime.tryParse(map['starts_at'] as String? ?? '') ??
          DateTime.now(),
      endsAt: map['ends_at'] == null
          ? null
          : DateTime.tryParse(map['ends_at'] as String),
    );
  }
}

class AdminManagementService {
  AdminManagementService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<bool> isCurrentUserAdmin() async {
    final result = await _client.rpc('is_admin');
    return result == true;
  }

  Future<AdminDashboardStats> dashboardStats() async {
    final result = await _client.rpc('admin_dashboard_stats');
    return AdminDashboardStats.fromMap(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<List<AdminUserRecord>> users() async {
    final rows = await _client.rpc('admin_list_users');
    return (rows as List)
        .map(
          (row) => AdminUserRecord.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<void> setUserSuspended({
    required String userId,
    required bool suspended,
  }) async {
    await _client.rpc(
      'admin_set_user_suspension',
      params: {
        'p_target_user_id': userId,
        'p_suspended': suspended,
      },
    );
  }

  Future<List<AdminServiceAlert>> alerts() async {
    final rows = await _client
        .from('alerts')
        .select('id,operator_id,title,body,severity,starts_at,ends_at')
        .order('starts_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map(
          (row) => AdminServiceAlert.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<void> createAlert({
    required String? operatorId,
    required String title,
    required String body,
    required String severity,
    required DateTime startsAt,
    required DateTime? endsAt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in required');
    await _client.from('alerts').insert({
      'operator_id': operatorId,
      'title': title.trim(),
      'body': body.trim(),
      'severity': severity,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'created_by': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> updateAlert({
    required String alertId,
    required String? operatorId,
    required String title,
    required String body,
    required String severity,
    required DateTime startsAt,
    required DateTime? endsAt,
  }) async {
    await _client.from('alerts').update({
      'operator_id': operatorId,
      'title': title.trim(),
      'body': body.trim(),
      'severity': severity,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', alertId);
  }

  Future<void> deleteAlert(String alertId) async {
    await _client.from('alerts').delete().eq('id', alertId);
  }
}
