import 'package:supabase_flutter/supabase_flutter.dart';

class StopReview {
  const StopReview({
    required this.id,
    required this.userId,
    required this.operatorId,
    required this.stopId,
    required this.rating,
    required this.comment,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.moderationStatus = 'pending',
    this.moderationNote,
  });

  final String id;
  final String userId;
  final String operatorId;
  final String stopId;
  final int rating;
  final String comment;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String moderationStatus;
  final String? moderationNote;

  bool get isApproved => moderationStatus == 'approved';
  bool get isPending => moderationStatus == 'pending';
  bool get isRejected => moderationStatus == 'rejected';
  bool get isHidden => moderationStatus == 'hidden';
  bool get canOwnerEdit => isPending;

  factory StopReview.fromMap(Map<String, dynamic> map) {
    return StopReview(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      operatorId: map['operator_id'] as String? ?? '',
      stopId: map['stop_id'] as String? ?? '',
      rating: (map['rating'] as num?)?.toInt() ?? 0,
      comment: map['comment'] as String? ?? '',
      displayName: map['display_name'] as String? ?? 'Commuter',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
      moderationStatus: map['moderation_status'] as String? ?? 'pending',
      moderationNote: map['moderation_note'] as String?,
    );
  }
}

class StopReviewsService {
  StopReviewsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<StopReview>> list({
    required String operatorId,
    required String stopId,
  }) async {
    final rows = await _client
        .from('stop_reviews')
        .select()
        .eq('operator_id', operatorId)
        .eq('stop_id', stopId)
        .order('updated_at', ascending: false)
        .limit(50);

    final reviews = (rows as List)
        .map((row) => StopReview.fromMap(row as Map<String, dynamic>))
        .toList();

    reviews.sort((a, b) {
      if (a.isApproved != b.isApproved) return a.isApproved ? -1 : 1;
      final rating = b.rating.compareTo(a.rating);
      if (rating != 0) return rating;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return reviews;
  }

  Future<void> create({
    required String operatorId,
    required String stopId,
    required int rating,
    required String comment,
    required String displayName,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Sign in required');

    await _client.from('stop_reviews').insert({
      'user_id': userId,
      'operator_id': operatorId,
      'stop_id': stopId,
      'rating': rating,
      'comment': comment.trim(),
      'display_name': displayName.trim().isEmpty ? 'Commuter' : displayName,
      'moderation_status': 'pending',
      'moderation_note': null,
      'moderated_at': null,
      'moderated_by': null,
    });
  }

  Future<void> updateOwn({
    required String reviewId,
    required int rating,
    required String comment,
    required String displayName,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Sign in required');

    final updated = await _client
        .from('stop_reviews')
        .update({
          'rating': rating,
          'comment': comment.trim(),
          'display_name': displayName.trim().isEmpty ? 'Commuter' : displayName,
          'moderation_status': 'pending',
          'moderation_note': null,
          'moderated_at': null,
          'moderated_by': null,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reviewId)
        .eq('user_id', userId)
        .eq('moderation_status', 'pending')
        .select('id');

    if ((updated as List).isEmpty) {
      throw StateError(
        'Only pending reviews can be edited. Delete and submit a new review instead.',
      );
    }
  }

  Future<void> deleteOwn(String reviewId) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _client
        .from('stop_reviews')
        .delete()
        .eq('id', reviewId)
        .eq('user_id', userId);
  }

  Future<void> report({
    required String reviewId,
    required String reason,
    String details = '',
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Sign in required');

    await _client.from('review_reports').upsert(
      {
        'review_id': reviewId,
        'reporter_id': userId,
        'reason': reason,
        'details': details.trim(),
        'status': 'open',
      },
      onConflict: 'review_id,reporter_id',
    );
  }
}
