import 'package:flutter_test/flutter_test.dart';
import 'package:xploremy/features/admin/admin_management_service.dart';

void main() {
  test('admin dashboard statistics map correctly', () {
    final stats = AdminDashboardStats.fromMap({
      'total_users': 24,
      'pending_reviews': 5,
      'open_reports': 3,
      'active_alerts': 2,
    });

    expect(stats.totalUsers, 24);
    expect(stats.pendingReviews, 5);
    expect(stats.openReports, 3);
    expect(stats.activeAlerts, 2);
  });

  test('admin user suspension state maps correctly', () {
    final user = AdminUserRecord.fromMap({
      'id': 'user-1',
      'email': 'user@example.com',
      'full_name': 'Test User',
      'role': 'user',
      'is_suspended': true,
      'created_at': '2026-09-17T00:00:00Z',
    });

    expect(user.isSuspended, isTrue);
    expect(user.isAdmin, isFalse);
  });

  test('service alert reports active state inside its time window', () {
    final now = DateTime.now();
    final alert = AdminServiceAlert(
      id: 'alert-1',
      operatorId: 'rapid-rail-kl',
      title: 'Delay',
      body: 'Service delay',
      severity: 'warning',
      startsAt: now.subtract(const Duration(minutes: 5)),
      endsAt: now.add(const Duration(minutes: 30)),
    );

    expect(alert.isActive, isTrue);
  });
}
