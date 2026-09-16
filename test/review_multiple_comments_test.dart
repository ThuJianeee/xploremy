import 'package:flutter_test/flutter_test.dart';
import 'package:xploremy/features/reviews/stop_reviews_service.dart';

void main() {
  test('multiple review rows from the same user and stop remain independent',
      () {
    final first = StopReview.fromMap({
      'id': 'review-1',
      'user_id': 'user-1',
      'operator_id': 'rapid-rail-kl',
      'stop_id': 'stop-1',
      'rating': 5,
      'comment': 'Clean station',
      'display_name': 'User',
      'moderation_status': 'pending',
      'created_at': '2026-09-16T00:00:00Z',
      'updated_at': '2026-09-16T00:00:00Z',
    });
    final second = StopReview.fromMap({
      'id': 'review-2',
      'user_id': 'user-1',
      'operator_id': 'rapid-rail-kl',
      'stop_id': 'stop-1',
      'rating': 4,
      'comment': 'Busy at peak hour',
      'display_name': 'User',
      'moderation_status': 'pending',
      'created_at': '2026-09-16T01:00:00Z',
      'updated_at': '2026-09-16T01:00:00Z',
    });

    expect(first.id, isNot(second.id));
    expect(first.userId, second.userId);
    expect(first.stopId, second.stopId);
    expect(first.comment, isNot(second.comment));
  });
}
