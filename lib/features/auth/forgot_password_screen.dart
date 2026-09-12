import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../widgets/status_banner.dart';
import 'auth_service.dart';
import 'auth_validators.dart';
import 'widgets/auth_success_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }

    final email = _email.text.trim();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await context.read<AuthService>().sendPasswordReset(email);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (successContext) => AuthSuccessScreen(
            title: 'Password reset email sent',
            message: 'We sent a password reset link to your email address. '
                'Open the email and follow the link to create a new password.',
            email: email,
            showExpiry: true,
            buttonText: 'Back to sign in',
            icon: Icons.mark_email_read_outlined,
            onPressed: () {
              Navigator.of(successContext).pop();
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = AuthValidators.friendlyError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reset password',
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
                  'Enter the Gmail address you registered with '
                  'and we’ll send you a password reset link.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.slate,
                      ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [
                    AutofillHints.email,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Gmail address',
                    hintText: 'example@gmail.com',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                    ),
                  ),
                  validator: AuthValidators.email,
                  onFieldSubmitted: (_) => _send(),
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
                  onPressed: _busy ? null : _send,
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
                          'Send reset link',
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
