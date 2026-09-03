import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../widgets/status_banner.dart';
import 'auth_service.dart';
import 'auth_validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();

  bool _busy = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _message = null;
      _isError = false;
    });

    try {
      await context.read<AuthService>().sendPasswordReset(
            _identifier.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _message = AuthService.isPhone(_identifier.text)
            ? 'A one-time SMS sign-in code was requested. After signing in, set a new password from Profile.'
            : 'Check your inbox for the password reset link.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _message = AuthValidators.friendlyError(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
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
                  'Enter the email or phone number you registered with and we’ll send reset instructions.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.slate,
                      ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _identifier,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Email or phone',
                    prefixIcon: Icon(Icons.help_outline),
                  ),
                  validator: AuthValidators.identifier,
                  onFieldSubmitted: (_) => _send(),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  StatusBanner(
                    message: _message!,
                    color: _isError ? AppTheme.hibiscus : AppTheme.signalTeal,
                    icon: _isError
                        ? Icons.error_outline
                        : Icons.mark_email_read_outlined,
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
                      : const Text('Send reset instructions'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
