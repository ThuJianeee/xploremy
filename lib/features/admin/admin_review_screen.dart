import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../reviews/stop_reviews_service.dart';
import 'admin_review_service.dart';

class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen>
    with SingleTickerProviderStateMixin {
  final AdminReviewService _service = AdminReviewService();
  late final TabController _tabs;
  bool _loading = true;
  bool _admin = false;
  String? _error;
  List<StopReview> _pending = const [];
  List<ReviewReport> _reports = const [];
  List<StopReview> _all = const [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
        if (mounted) {
          setState(() {
            _admin = false;
            _loading = false;
          });
        }
        return;
      }
      final values = await Future.wait([
        _service.reviews(status: 'pending'),
        _service.reports(),
        _service.reviews(),
      ]);
      if (!mounted) return;
      setState(() {
        _admin = true;
        _pending = values[0] as List<StopReview>;
        _reports = values[1] as List<ReviewReport>;
        _all = values[2] as List<StopReview>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            'Admin moderation could not be loaded. Apply the latest Supabase SQL and try again.';
        _loading = false;
      });
    }
  }

  Future<String?> _noteDialog(String title) async {
    var note = '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          maxLines: 3,
          maxLength: 250,
          onChanged: (value) => note = value,
          decoration: const InputDecoration(
            labelText: 'Moderation note (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, note),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _moderate(StopReview review, String status) async {
    final note = await _noteDialog(
      status == 'approved'
          ? 'Approve review?'
          : status == 'hidden'
              ? 'Hide review?'
              : 'Reject review?',
    );
    if (note == null) return;
    try {
      await _service.moderateReview(
        reviewId: review.id,
        status: status,
        note: note,
      );
      await _load();
    } catch (_) {
      _showActionError('Could not update this review.');
    }
  }

  Future<void> _delete(StopReview review) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete review permanently?'),
        content: const Text(
            'This also removes related reports and cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _service.deleteReview(review.id);
      await _load();
    } catch (_) {
      _showActionError('Could not delete this review.');
    }
  }

  Future<void> _handleReport(ReviewReport report, String action) async {
    final review = report.review;
    try {
      if (action == 'hide' && review != null) {
        await _service.moderateReview(
          reviewId: review.id,
          status: 'hidden',
          note: 'Hidden after user report.',
        );
        await _service.resolveReport(reportId: report.id, status: 'resolved');
      } else if (action == 'delete' && review != null) {
        await _service.deleteReview(review.id);
      } else {
        await _service.resolveReport(reportId: report.id, status: 'dismissed');
      }
      await _load();
    } catch (_) {
      _showActionError('Could not process this report.');
    }
  }

  void _showActionError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _reviewCard(StopReview review, {bool moderationActions = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusChip(review.moderationStatus),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${review.operatorId} · Stop ${review.stopId}',
              style: const TextStyle(color: AppTheme.slate, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              'User ${_shortId(review.userId)} · Review ${_shortId(review.id)} · ${_timeLabel(review.updatedAt)}',
              style: const TextStyle(color: AppTheme.slate, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= review.rating ? Icons.star : Icons.star_border,
                    size: 18,
                    color: Colors.amber.shade700,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Comment',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(
              review.comment.trim().isEmpty
                  ? '(Rating only — no text comment)'
                  : review.comment,
              style: TextStyle(
                color: review.comment.trim().isEmpty ? AppTheme.slate : null,
              ),
            ),
            if (review.moderationNote?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Note: ${review.moderationNote}',
                style: const TextStyle(color: AppTheme.slate, fontSize: 12),
              ),
            ],
            if (moderationActions) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _moderate(review, 'approved'),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Approve'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _moderate(review, 'rejected'),
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('Reject'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _moderate(review, 'hidden'),
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: const Text('Hide'),
                  ),
                  TextButton.icon(
                    onPressed: () => _delete(review),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _shortId(String value) {
    if (value.length <= 8) return value;
    return value.substring(0, 8);
  }

  String _timeLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _pendingTab() {
    if (_pending.isEmpty) {
      return const _EmptyState(
        icon: Icons.task_alt,
        title: 'No reviews waiting for approval',
        subtitle: 'New or edited user reviews will appear here as Pending.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final review in _pending)
          _reviewCard(review, moderationActions: true)
      ],
    );
  }

  Widget _reportsTab() {
    if (_reports.isEmpty) {
      return const _EmptyState(
        icon: Icons.report_gmailerrorred_outlined,
        title: 'No open reports',
        subtitle: 'User reports about inappropriate reviews will appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final report in _reports)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.reason,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (report.details.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(report.details),
                  ],
                  const SizedBox(height: 10),
                  if (report.review != null) _reviewCard(report.review!),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _handleReport(report, 'hide'),
                        child: const Text('Hide review'),
                      ),
                      OutlinedButton(
                        onPressed: () => _handleReport(report, 'delete'),
                        child: const Text('Delete review'),
                      ),
                      TextButton(
                        onPressed: () => _handleReport(report, 'dismiss'),
                        child: const Text('Dismiss report'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _allTab() {
    if (_all.isEmpty) {
      return const _EmptyState(
        icon: Icons.reviews_outlined,
        title: 'No reviews yet',
        subtitle: 'Submitted reviews will be listed here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final review in _all) _reviewCard(review, moderationActions: true)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin · Review Moderation'),
        bottom: _admin
            ? TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: 'Pending (${_pending.length})'),
                  Tab(text: 'Reports (${_reports.length})'),
                  Tab(text: 'All (${_all.length})'),
                ],
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load admin moderation',
                  subtitle: _error!,
                )
              : !_admin
                  ? const _EmptyState(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Admin access required',
                      subtitle:
                          'Set this account role to admin in Supabase before opening the moderation dashboard.',
                    )
                  : TabBarView(
                      controller: _tabs,
                      children: [_pendingTab(), _reportsTab(), _allTab()],
                    ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(status.toUpperCase()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
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
            Icon(icon, size: 48, color: AppTheme.slate),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
