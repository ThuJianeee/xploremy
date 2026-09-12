import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../widgets/password_field.dart';
import '../../widgets/status_banner.dart';
import 'auth_service.dart';
import 'auth_validators.dart';
import 'widgets/auth_success_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  StreamSubscription<AuthState>? _authSubscription;

  bool _busy = false;
  bool _awaitingEmailVerification = false;
  bool _handlingEmailVerification = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        unawaited(_handleAuthStateChange(state));
      },
    );
  }

  Future<void> _handleAuthStateChange(
    AuthState state,
  ) async {
    if (!_awaitingEmailVerification ||
        _handlingEmailVerification ||
        state.event != AuthChangeEvent.signedIn ||
        state.session == null) {
      return;
    }

    _handlingEmailVerification = true;

    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await auth.signOut();

      if (!mounted) return;

      Navigator.of(context).popUntil(
        (route) => route.isFirst,
      );

      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Email verified successfully. Please sign in.',
                ),
              ),
            );
        },
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Email verified, but XploreMY could not return to sign in. '
            'Please go back and sign in manually.';
      });
    } finally {
      _handlingEmailVerification = false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();

    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });

    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await context.read<AuthService>().register(
            email: _email.text.trim(),
            password: _password.text,
            fullName: _name.text.trim(),
          );

      if (!mounted) return;

      setState(() {
        _awaitingEmailVerification = true;
      });
    } catch (e) {
      if (!mounted) return;

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
    if (_awaitingEmailVerification) {
      return AuthSuccessScreen(
        title: 'Verification email sent',
        message: 'We sent a verification link to your Gmail address. '
            'Open the email and confirm your account before signing in.',
        email: _email.text.trim(),
        showExpiry: true,
        buttonText: 'Back to sign in',
        icon: Icons.mark_email_read_outlined,
        onPressed: () {
          Navigator.of(context).pop();
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
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
                  'Create an account to save your favourite stops '
                  'and sync them across devices.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.slate,
                      ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                    ),
                  ),
                  validator: AuthValidators.fullName,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
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
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _password,
                  label: 'Password',
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
                  label: 'Confirm password',
                  prefixIcon: Icons.lock_reset_outlined,
                  validator: (value) => AuthValidators.confirmPassword(
                    value,
                    _password.text,
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
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
                  onPressed: _busy ? null : _submit,
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
                          'Create account',
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
