import 'package:supabase_flutter/supabase_flutter.dart';

import '../reviews/stop_reviews_service.dart';

class ReviewReport {
  const ReviewReport({
    required this.id,
    required this.reviewId,
    required this.reporterId,
    required this.reason,
    required this.details,
    required this.status,
    required this.createdAt,
    this.review,
  });

  final String id;
  final String reviewId;
  final String reporterId;
  final String reason;
  final String details;
  final String status;
  final DateTime createdAt;
  final StopReview? review;

  ReviewReport copyWithReview(StopReview? value) => ReviewReport(
        id: id,
        reviewId: reviewId,
        reporterId: reporterId,
        reason: reason,
        details: details,
        status: status,
        createdAt: createdAt,
        review: value,
      );

  factory ReviewReport.fromMap(Map<String, dynamic> map) => ReviewReport(
        id: map['id'] as String? ?? '',
        reviewId: map['review_id'] as String? ?? '',
        reporterId: map['reporter_id'] as String? ?? '',
        reason: map['reason'] as String? ?? 'Other',
        details: map['details'] as String? ?? '',
        status: map['status'] as String? ?? 'open',
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class AdminReviewService {
  AdminReviewService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<bool> isCurrentUserAdmin() async {
    final result = await _client.rpc('is_admin');
    return result == true;
  }

  Future<List<StopReview>> reviews({String? status}) async {
    final rows = status == null
        ? await _client
            .from('stop_reviews')
            .select()
            .order('updated_at', ascending: false)
            .limit(100)
        : await _client
            .from('stop_reviews')
            .select()
            .eq('moderation_status', status)
            .order('updated_at', ascending: false)
            .limit(100);
    return (rows as List)
        .map((row) => StopReview.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReviewReport>> reports({String status = 'open'}) async {
    final rows = await _client
        .from('review_reports')
        .select()
        .eq('status', status)
        .order('created_at', ascending: false)
        .limit(100);

    final reports = (rows as List)
        .map((row) => ReviewReport.fromMap(row as Map<String, dynamic>))
        .toList();

    final result = <ReviewReport>[];
    for (final report in reports) {
      final row = await _client
          .from('stop_reviews')
          .select()
          .eq('id', report.reviewId)
          .maybeSingle();
      result.add(
        report.copyWithReview(
          row == null ? null : StopReview.fromMap(row),
        ),
      );
    }
    return result;
  }

  Future<void> moderateReview({
    required String reviewId,
    required String status,
    String note = '',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in required');

    await _client.from('stop_reviews').update({
      'moderation_status': status,
      'moderation_note': note.trim().isEmpty ? null : note.trim(),
      'moderated_by': userId,
      'moderated_at': DateTime.now().toIso8601String(),
    }).eq('id', reviewId);
  }

  Future<void> deleteReview(String reviewId) async {
    await _client.from('stop_reviews').delete().eq('id', reviewId);
  }

  Future<void> resolveReport({
    required String reportId,
    required String status,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in required');

    await _client.from('review_reports').update({
      'status': status,
      'resolved_by': userId,
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', reportId);
  }
}
