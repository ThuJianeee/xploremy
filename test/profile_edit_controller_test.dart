import 'package:flutter_test/flutter_test.dart';
import 'package:xploremy/features/profile/profile_edit_controller.dart';

void main() {
  test('tracks and discards unsaved profile edits', () {
    final controller = ProfileEditController();
    var discarded = false;

    controller.attachDiscard(() => discarded = true);
    controller.setDirty(true);

    expect(controller.isDirty, isTrue);

    controller.discardChanges();

    expect(discarded, isTrue);
    expect(controller.isDirty, isFalse);

    controller.dispose();
  });
}
