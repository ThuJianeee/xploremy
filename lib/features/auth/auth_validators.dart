class AuthValidators {
  AuthValidators._();

  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static final RegExp _phonePattern = RegExp(r'^\+?[0-9 \-]{7,15}$');

  static String? fullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Please enter your name';
    if (name.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? identifier(String? value) {
    final identifier = value?.trim() ?? '';
    if (identifier.isEmpty) return 'Please enter your email or phone number';

    if (identifier.contains('@')) {
      if (!_emailPattern.hasMatch(identifier)) return 'Enter a valid email address';
      return null;
    }

    if (!_phonePattern.hasMatch(identifier)) {
      return 'Enter a valid email or phone number';
    }
    return null;
  }

  static String? loginPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Please enter your password';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? strongPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Please enter your password';
    if (password.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Add at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Add at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Add at least one number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    final confirm = value ?? '';
    if (confirm.isEmpty) return 'Please confirm your password';
    if (confirm != password) return 'Passwords do not match';
    return null;
  }

  static String friendlyError(Object error) {
    final text = error.toString().replaceFirst('AuthApiException: ', '');
    final lower = text.toLowerCase();

    if (lower.contains('invalid login credentials')) {
      return 'That email/phone and password combination did not match.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please confirm your email address first.';
    }
    if (lower.contains('user already registered')) {
      return 'An account already exists for this email.';
    }
    if (lower.contains('password is known to be weak') ||
        lower.contains('weakpasswordexception') ||
        lower.contains('pwned')) {
      return 'This password is too common. Please choose a stronger password.';
    }
    if (lower.contains('pgrst205') ||
        lower.contains('could not find the table') ||
        lower.contains('schema cache')) {
      return 'Cloud profile storage is not set up yet. Your account details are still available on this device.';
    }
    if (lower.contains('socket') || lower.contains('network')) {
      return 'Unable to connect. Please check your internet connection.';
    }
    return text;
  }
}
