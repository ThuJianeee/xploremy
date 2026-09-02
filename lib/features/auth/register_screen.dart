import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import 'auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _otp = TextEditingController();

  bool _busy = false;
  bool _awaitingOtp = false;

  String? _error;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _identifier.dispose();
    _password.dispose();
    _confirm.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _notice = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _busy = true;
    });

    final auth = context.read<AuthService>();

    try {
      await auth.register(
        identifier: _identifier.text.trim(),
        password: _password.text,
        fullName: _name.text.trim(),
      );

      if (!mounted) return;

      if (AuthService.isPhone(_identifier.text)) {
        setState(() {
          _awaitingOtp = true;
          _notice =
          'We sent a 6-digit code by SMS. Enter it below to finish.';
        });
      } else {
        setState(() {
          _notice =
          'Account created. Check your inbox to confirm your email, then sign in.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        final message =
        e.toString().replaceFirst('AuthApiException: ', '');

        if (message.contains('WeakPasswordException') ||
            message.toLowerCase().contains('password is known to be weak') ||
            message.toLowerCase().contains('pwned')) {
          _error =
          'This password is too common. Please choose a stronger password.';
        } else {
          _error = message;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _verify() async {
    setState(() {
      _error = null;
      _notice = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await context.read<AuthService>().verifyPhoneOtp(
        phone: _identifier.text.trim(),
        token: _otp.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            e.toString().replaceFirst('AuthApiException: ', '');
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
        title: const Text('Create account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Save your favourite stops and sync them across devices.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    color: AppTheme.slate,
                  ),
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller: _name,
                  enabled: !_awaitingOtp,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                    ),
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';

                    if (name.isEmpty) {
                      return 'Please enter your name';
                    }

                    if (name.length < 2) {
                      return 'Name must be at least 2 characters';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: _identifier,
                  enabled: !_awaitingOtp,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email or phone number',
                    hintText: 'you@email.com or 012-345 6789',
                    prefixIcon: Icon(
                      Icons.alternate_email,
                    ),
                  ),
                  validator: (value) {
                    final identifier = value?.trim() ?? '';

                    if (identifier.isEmpty) {
                      return 'Please enter your email or phone number';
                    }

                    final looksEmail =
                        identifier.contains('@') &&
                            identifier.contains('.');

                    if (!looksEmail &&
                        !AuthService.isPhone(identifier)) {
                      return 'Enter a valid email or Malaysian phone number';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: _password,
                  obscureText: true,
                  enabled: !_awaitingOtp,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(
                      Icons.lock_outline,
                    ),
                  ),
                  validator: (value) {
                    final password = value ?? '';

                    if (password.isEmpty) {
                      return 'Please enter your password';
                    }

                    if (password.length < 8) {
                      return 'Password must be at least 8 characters';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  enabled: !_awaitingOtp,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: Icon(
                      Icons.lock_reset_outlined,
                    ),
                  ),
                  validator: (value) {
                    final confirmPassword = value ?? '';

                    if (confirmPassword.isEmpty) {
                      return 'Please confirm your password';
                    }

                    if (confirmPassword != _password.text) {
                      return 'Passwords do not match';
                    }

                    return null;
                  },
                ),

                if (_awaitingOtp) ...[
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'SMS code',
                      prefixIcon: Icon(
                        Icons.sms_outlined,
                      ),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (!_awaitingOtp) {
                        return null;
                      }

                      final code = value?.trim() ?? '';

                      if (code.isEmpty) {
                        return 'Please enter the SMS code';
                      }

                      if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                        return 'Enter the 6-digit SMS code';
                      }

                      return null;
                    },
                  ),
                ],

                if (_notice != null) ...[
                  const SizedBox(height: 16),

                  _Banner(
                    message: _notice!,
                    color: AppTheme.signalTeal,
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 16),

                  _Banner(
                    message: _error!,
                    color: AppTheme.hibiscus,
                  ),
                ],

                const SizedBox(height: 24),

                FilledButton(
                  onPressed: _busy
                      ? null
                      : (_awaitingOtp ? _verify : _submit),
                  child: Text(
                    _awaitingOtp
                        ? 'Verify code'
                        : 'Create account',
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

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.color,
  });

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: color,
          fontSize: 13,
        ),
      ),
    );
  }
}