import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'admin_management_service.dart';
import 'admin_review_screen.dart';
import 'admin_service_alerts_screen.dart';
import 'admin_users_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminManagementService _service = AdminManagementService();
  bool _loading = true;
  bool _admin = false;
  String? _error;
  AdminDashboardStats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final isAdmin = await _service.isCurrentUserAdmin();
      if (!isAdmin) {
        if (!mounted) return;
        setState(() {
          _admin = false;
          _loading = false;
        });
        return;
      }
      final stats = await _service.dashboardStats();
      if (!mounted) return;
      setState(() {
        _admin = true;
        _stats = stats;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Admin dashboard could not be loaded. Apply the latest Supabase SQL and try again.';
        _loading = false;
      });
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin dashboard'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _AdminMessage(
                  icon: Icons.error_outline,
                  title: 'Could not load admin dashboard',
                  subtitle: _error!,
                )
              : !_admin
                  ? const _AdminMessage(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Admin access required',
                      subtitle:
                          'Only accounts with the admin role can open this dashboard.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: [
                          const Text(
                            'Overview',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.45,
                            children: [
                              _StatCard(
                                label: 'Total users',
                                value: _stats?.totalUsers ?? 0,
                                icon: Icons.people_outline,
                              ),
                              _StatCard(
                                label: 'Pending reviews',
                                value: _stats?.pendingReviews ?? 0,
                                icon: Icons.rate_review_outlined,
                              ),
                              _StatCard(
                                label: 'Open reports',
                                value: _stats?.openReports ?? 0,
                                icon: Icons.report_outlined,
                              ),
                              _StatCard(
                                label: 'Active alerts',
                                value: _stats?.activeAlerts ?? 0,
                                icon: Icons.campaign_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Management',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _AdminMenuCard(
                            icon: Icons.manage_accounts_outlined,
                            title: 'User management',
                            subtitle:
                                'View users and suspend or restore account access',
                            onTap: () => _open(const AdminUsersScreen()),
                          ),
                          _AdminMenuCard(
                            icon: Icons.fact_check_outlined,
                            title: 'Review moderation',
                            subtitle: 'Approve reviews and handle user reports',
                            onTap: () => _open(const AdminReviewScreen()),
                          ),
                          _AdminMenuCard(
                            icon: Icons.notification_important_outlined,
                            title: 'Service alert management',
                            subtitle:
                                'Create, edit and delete operator service notices',
                            onTap: () =>
                                _open(const AdminServiceAlertsScreen()),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.signalTeal),
            const Spacer(),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: AppTheme.slate),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  const _AdminMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Icon(icon, color: AppTheme.trackNavy),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _AdminMessage extends StatelessWidget {
  const _AdminMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppTheme.slate),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.slate),
            ),
          ],
        ),
      ),
    );
  }
}
