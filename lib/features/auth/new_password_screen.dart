import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../widgets/password_field.dart';
import '../../widgets/status_banner.dart';
import 'auth_service.dart';
import 'auth_validators.dart';

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _updated = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }

    final auth = context.read<AuthService>();
    final newPassword = _password.text;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await Future<void>.delayed(
        const Duration(milliseconds: 200),
      );

      if (!mounted) {
        return;
      }

      await auth.completePasswordRecovery(
        newPassword,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
        _updated = true;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
        _error = AuthValidators.friendlyError(e);
      });
    }
  }

  Future<void> _backToSignIn() async {
    if (_busy) {
      return;
    }

    final auth = context.read<AuthService>();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await auth.finishPasswordRecovery();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
        _error = AuthValidators.friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!_updated && auth.isPasswordRecovery && !auth.isSignedIn) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Reset password'),
        ),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 18),
                  Text(
                    'Verifying your password reset link…',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_updated) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('XploreMY'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 80,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Password updated',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your password has been changed successfully. '
                      'You can now sign in using your new password.',
                      textAlign: TextAlign.center,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      StatusBanner(
                        message: _error!,
                        color: AppTheme.hibiscus,
                        icon: Icons.error_outline,
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _backToSignIn,
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Back to sign in',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Create new password',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your reset link was verified. '
                  'Choose a new password for your '
                  'XploreMY account.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.slate,
                      ),
                ),
                const SizedBox(height: 20),
                PasswordField(
                  controller: _password,
                  label: 'New password',
                  validator: AuthValidators.strongPassword,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 6),
                Text(
                  'Use 8+ characters with uppercase, '
                  'lowercase and a number.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.slate,
                      ),
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _confirm,
                  label: 'Confirm new password',
                  prefixIcon: Icons.lock_reset_outlined,
                  validator: (value) => AuthValidators.confirmPassword(
                    value,
                    _password.text,
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  StatusBanner(
                    message: _error!,
                    color: AppTheme.hibiscus,
                    icon: Icons.error_outline,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Update password',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
