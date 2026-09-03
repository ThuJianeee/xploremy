import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../widgets/password_field.dart';
import '../../widgets/status_banner.dart';
import 'auth_service.dart';
import 'auth_validators.dart';

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

  StreamSubscription<AuthState>? _authSubscription;

  bool _busy = false;
  bool _awaitingOtp = false;
  bool _awaitingEmailVerification = false;
  bool _handlingEmailVerification = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      unawaited(_handleAuthStateChange(state));
    });
  }

  Future<void> _handleAuthStateChange(AuthState state) async {
    if (!_awaitingEmailVerification ||
        _handlingEmailVerification ||
        state.event != AuthChangeEvent.signedIn ||
        state.session == null) {
      return;
    }

    _handlingEmailVerification = true;
    _awaitingEmailVerification = false;

    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await auth.signOut();
      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Email verified successfully. Please sign in.',
              ),
            ),
          );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Email verified, but XploreMY could not return to sign in. Please go back and sign in manually.';
      });
    } finally {
      _handlingEmailVerification = false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
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

    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      await context.read<AuthService>().register(
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
          _awaitingEmailVerification = true;
          _notice = 'Account created. Check your inbox to confirm your email.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AuthValidators.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _error = null;
      _notice = null;
    });

    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      await context.read<AuthService>().verifyPhoneOtp(
            phone: _identifier.text.trim(),
            token: _otp.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AuthValidators.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formEnabled = !_awaitingOtp && !_awaitingEmailVerification;

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
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
                  'Save your favourite stops and sync them across devices.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.slate,
                      ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _name,
                  enabled: formEnabled,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: AuthValidators.fullName,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _identifier,
                  enabled: formEnabled,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email or phone number',
                    hintText: 'you@email.com or 012-345 6789',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: AuthValidators.identifier,
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _password,
                  label: 'Password',
                  enabled: formEnabled,
                  validator: AuthValidators.strongPassword,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 6),
                Text(
                  'Use 8+ characters with uppercase, lowercase and a number.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.slate,
                      ),
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _confirm,
                  label: 'Confirm password',
                  enabled: formEnabled,
                  prefixIcon: Icons.lock_reset_outlined,
                  validator: (value) => AuthValidators.confirmPassword(
                    value,
                    _password.text,
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_awaitingOtp) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'SMS code',
                      prefixIcon: Icon(Icons.sms_outlined),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (!_awaitingOtp) return null;
                      final code = value?.trim() ?? '';
                      if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                        return 'Enter the 6-digit SMS code';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _verify(),
                  ),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 16),
                  StatusBanner(
                    message: _notice!,
                    color: AppTheme.signalTeal,
                    icon: Icons.mark_email_read_outlined,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  StatusBanner(
                    message: _error!,
                    color: AppTheme.hibiscus,
                    icon: Icons.error_outline,
                  ),
                ],
                const SizedBox(height: 24),
                if (_awaitingEmailVerification)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.login),
                    label: const Text('Back to sign in'),
                  )
                else
                  FilledButton(
                    onPressed: _busy ? null : (_awaitingOtp ? _verify : _submit),
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_awaitingOtp ? 'Verify code' : 'Create account'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
