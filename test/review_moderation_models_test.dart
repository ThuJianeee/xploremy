import 'package:flutter_test/flutter_test.dart';
import 'package:xploremy/features/reviews/stop_reviews_service.dart';

void main() {
  test('review moderation status is parsed', () {
    final review = StopReview.fromMap({
      'id': 'r1',
      'user_id': 'u1',
      'operator_id': 'rapid-rail-kl',
      'stop_id': 's1',
      'rating': 5,
      'comment': 'Useful interchange',
      'display_name': 'Commuter',
      'moderation_status': 'pending',
      'created_at': '2026-09-16T00:00:00Z',
      'updated_at': '2026-09-16T00:00:00Z',
    });

    expect(review.isPending, isTrue);
    expect(review.isApproved, isFalse);
  });

  test('only pending reviews are editable by their owner', () {
    StopReview reviewWithStatus(String status) => StopReview.fromMap({
          'id': 'r-$status',
          'user_id': 'u1',
          'operator_id': 'rapid-rail-kl',
          'stop_id': 's1',
          'rating': 4,
          'comment': 'Comment',
          'display_name': 'Commuter',
          'moderation_status': status,
          'created_at': '2026-09-16T00:00:00Z',
          'updated_at': '2026-09-16T00:00:00Z',
        });

    expect(reviewWithStatus('pending').canOwnerEdit, isTrue);
    expect(reviewWithStatus('approved').canOwnerEdit, isFalse);
    expect(reviewWithStatus('rejected').canOwnerEdit, isFalse);
    expect(reviewWithStatus('hidden').canOwnerEdit, isFalse);
  });
}
