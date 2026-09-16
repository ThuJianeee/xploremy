import 'package:flutter_test/flutter_test.dart';
import 'package:xploremy/features/auth/auth_service.dart';

void main() {
  test('recognises the XploreMY password reset deep link', () {
    expect(
      isPasswordResetDeepLink(Uri.parse('xploremy://reset-password')),
      isTrue,
    );
    expect(
      isPasswordResetDeepLink(Uri.parse('xploremy://login-callback')),
      isFalse,
    );
    expect(isPasswordResetDeepLink(null), isFalse);
  });
}
