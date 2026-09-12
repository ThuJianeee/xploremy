class AuthValidators {
  AuthValidators._();

  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static String? fullName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Please enter your name';
    }

    if (name.length < 2) {
      return 'Name must be at least 2 characters';
    }

    return null;
  }

  static String? email(String? value) {
    final email = value?.trim().toLowerCase() ?? '';

    if (email.isEmpty) {
      return 'Please enter your Gmail address';
    }

    if (!_emailPattern.hasMatch(email)) {
      return 'Enter a valid Gmail address';
    }

    if (!email.endsWith('@gmail.com')) {
      return 'Please use a Gmail address';
    }

    return null;
  }

  static String? loginPassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Please enter your password';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    return null;
  }

  static String? strongPassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Please enter your password';
    }

    if (password.length < 8) {
      return 'Use at least 8 characters';
    }

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

  static String? confirmPassword(
    String? value,
    String password,
  ) {
    final confirm = value ?? '';

    if (confirm.isEmpty) {
      return 'Please confirm your password';
    }

    if (confirm != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  static String friendlyError(Object error) {
    final text = error.toString().replaceFirst('AuthApiException: ', '');

    final lower = text.toLowerCase();

    if (lower.contains('invalid login credentials')) {
      return 'The Gmail address or password is incorrect.';
    }

    if (lower.contains('email not confirmed')) {
      return 'Please confirm your Gmail address first.';
    }

    if (lower.contains('user already registered')) {
      return 'An account already exists for this Gmail address.';
    }

    if (lower.contains('over_email_send_rate_limit') ||
        lower.contains('email rate limit exceeded') ||
        lower.contains('statuscode: 429')) {
      return 'Too many emails have been requested. '
          'Please wait a while and try again.';
    }

    if (lower.contains('otp_expired') ||
        lower.contains('token has expired') ||
        lower.contains('expired')) {
      return 'This email link has expired. '
          'Please request a new one.';
    }

    if (lower.contains('same_password') ||
        lower.contains('new password should be different')) {
      return 'Your new password must be different '
          'from your current password.';
    }

    if (lower.contains('password is known to be weak') ||
        lower.contains('weakpasswordexception') ||
        lower.contains('pwned')) {
      return 'This password is too common. '
          'Please choose a stronger password.';
    }

    if (lower.contains('pgrst205') ||
        lower.contains('could not find the table') ||
        lower.contains('schema cache')) {
      return 'Cloud profile storage is not available right now.';
    }

    if (lower.contains('socket') || lower.contains('network')) {
      return 'Unable to connect. '
          'Please check your internet connection.';
    }

    return text;
  }
}
