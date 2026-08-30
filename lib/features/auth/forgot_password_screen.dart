import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import 'auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
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
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await context.read<AuthService>().sendPasswordReset(_identifier.text);
      setState(() {
        _isError = false;
        _message = AuthService.isPhone(_identifier.text)
            ? 'We sent a one-time code by SMS. Use it to sign in, then set a new password from your profile.'
            : 'Check your inbox for a reset link.';
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _message = e.toString().replaceFirst('AuthApiException: ', '');
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the email or phone number you registered with and we\u2019ll send you a way back in.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.slate),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _identifier,
                decoration: const InputDecoration(
                  labelText: 'Email or phone',
                  prefixIcon: Icon(Icons.help_outline),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_isError ? AppTheme.hibiscus : AppTheme.signalTeal)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _isError ? AppTheme.hibiscus : AppTheme.signalTeal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _send,
                child: const Text('Send reset instructions'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
