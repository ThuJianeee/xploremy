import 'package:flutter_test/flutter_test.dart';
import 'package:xploremy/features/auth/auth_validators.dart';

void main() {
  group('AuthValidators', () {
    test('accepts a valid email', () {
      expect(AuthValidators.identifier('user@example.com'), isNull);
    });

    test('rejects an invalid email', () {
      expect(AuthValidators.identifier('user@invalid'), isNotNull);
    });

    test('accepts a Malaysian-style phone number', () {
      expect(AuthValidators.identifier('012-345 6789'), isNull);
    });

    test('strong password requires mixed case and a number', () {
      expect(AuthValidators.strongPassword('password1'), isNotNull);
      expect(AuthValidators.strongPassword('Password'), isNotNull);
      expect(AuthValidators.strongPassword('Password1'), isNull);
    });


    test('full name is required', () {
      expect(AuthValidators.fullName(''), isNotNull);
      expect(AuthValidators.fullName('A'), isNotNull);
      expect(AuthValidators.fullName('Yeoh Ka Hou'), isNull);
    });

    test('missing Supabase table is shown as a friendly message', () {
      final message = AuthValidators.friendlyError(
        'PostgrestException(message: Could not find the table public.profiles in the schema cache, code: PGRST205)',
      );
      expect(message, contains('Cloud profile storage is not set up yet'));
    });

    test('confirm password must match', () {
      expect(
        AuthValidators.confirmPassword('Password2', 'Password1'),
        isNotNull,
      );
      expect(
        AuthValidators.confirmPassword('Password1', 'Password1'),
        isNull,
      );
    });
  });
}
