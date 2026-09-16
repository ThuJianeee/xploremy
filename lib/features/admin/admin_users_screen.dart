import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import 'admin_management_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminManagementService _service = AdminManagementService();
  bool _loading = true;
  String? _error;
  String _query = '';
  List<AdminUserRecord> _users = const [];

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
      final users = await _service.users();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Users could not be loaded. Apply the latest Supabase SQL and confirm this account is an admin.';
        _loading = false;
      });
    }
  }

  Future<void> _toggleSuspension(AdminUserRecord user) async {
    if (user.isAdmin) {
      _showMessage('Admin accounts are protected from suspension.');
      return;
    }
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (user.id == currentUserId) {
      _showMessage('You cannot suspend your own admin account.');
      return;
    }
    final suspend = !user.isSuspended;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(suspend ? 'Suspend user?' : 'Restore user access?'),
        content: Text(
          suspend
              ? '${_displayName(user)} will be signed out when the app checks the profile and will not be able to sign in again until restored.'
              : '${_displayName(user)} will be allowed to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(suspend ? 'Suspend' : 'Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.setUserSuspended(
        userId: user.id,
        suspended: suspend,
      );
      await _load();
      _showMessage(suspend ? 'User suspended.' : 'User access restored.');
    } catch (_) {
      _showMessage('Could not update this user.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _displayName(AdminUserRecord user) {
    if (user.fullName.trim().isNotEmpty) return user.fullName.trim();
    if (user.email.trim().isNotEmpty) return user.email.trim();
    return 'User';
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final lower = _query.trim().toLowerCase();
    final visible = lower.isEmpty
        ? _users
        : _users.where((user) {
            return user.email.toLowerCase().contains(lower) ||
                user.fullName.toLowerCase().contains(lower) ||
                user.role.toLowerCase().contains(lower);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin · User management'),
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      TextField(
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'Search users',
                          hintText: 'Name, email or role',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${visible.length} user${visible.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: AppTheme.slate,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (visible.isEmpty)
                        const Card(
                          child: ListTile(
                            leading: Icon(Icons.person_search_outlined),
                            title: Text('No users found'),
                          ),
                        )
                      else
                        for (final user in visible)
                          Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        child: Text(
                                          _displayName(user)
                                              .substring(0, 1)
                                              .toUpperCase(),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _displayName(user),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            if (user.email.isNotEmpty)
                                              Text(
                                                user.email,
                                                style: const TextStyle(
                                                  color: AppTheme.slate,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          user.isSuspended
                                              ? 'SUSPENDED'
                                              : 'ACTIVE',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Chip(
                                          label: Text(user.role.toUpperCase())),
                                      Chip(
                                        label: Text(
                                          'Joined ${_dateLabel(user.createdAt)}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      onPressed: user.isAdmin
                                          ? null
                                          : () => _toggleSuspension(user),
                                      icon: Icon(
                                        user.isAdmin
                                            ? Icons.verified_user_outlined
                                            : user.isSuspended
                                                ? Icons.lock_open_outlined
                                                : Icons.block_outlined,
                                      ),
                                      label: Text(
                                        user.isAdmin
                                            ? 'Admin protected'
                                            : user.isSuspended
                                                ? 'Restore access'
                                                : 'Suspend user',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}
