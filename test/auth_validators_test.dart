import 'package:flutter_test/flutter_test.dart';
import 'package:xploremy/features/auth/auth_validators.dart';

void main() {
  group('AuthValidators email', () {
    test('accepts valid Gmail address', () {
      expect(
        AuthValidators.email('user@gmail.com'),
        isNull,
      );
    });

    test('accepts uppercase Gmail address', () {
      expect(
        AuthValidators.email('USER@GMAIL.COM'),
        isNull,
      );
    });

    test('rejects empty email', () {
      expect(
        AuthValidators.email(''),
        isNotNull,
      );
    });

    test('rejects invalid email format', () {
      expect(
        AuthValidators.email('user@invalid'),
        isNotNull,
      );
    });

    test('rejects non-Gmail address', () {
      expect(
        AuthValidators.email('user@yahoo.com'),
        isNotNull,
      );
    });
  });

  group('AuthValidators password', () {
    test('accepts valid strong password', () {
      expect(
        AuthValidators.strongPassword('Password1'),
        isNull,
      );
    });

    test('rejects short password', () {
      expect(
        AuthValidators.strongPassword('Pass1'),
        isNotNull,
      );
    });

    test('rejects password without uppercase', () {
      expect(
        AuthValidators.strongPassword('password1'),
        isNotNull,
      );
    });

    test('rejects password without lowercase', () {
      expect(
        AuthValidators.strongPassword('PASSWORD1'),
        isNotNull,
      );
    });

    test('rejects password without number', () {
      expect(
        AuthValidators.strongPassword('Password'),
        isNotNull,
      );
    });

    test('confirm password must match', () {
      expect(
        AuthValidators.confirmPassword(
          'Password1',
          'Password1',
        ),
        isNull,
      );

      expect(
        AuthValidators.confirmPassword(
          'Password2',
          'Password1',
        ),
        isNotNull,
      );
    });
  });
}
