import 'package:flutter/material.dart';

import '../../../widgets/password_field.dart';
import '../../auth/auth_validators.dart';

Future<String?> showChangePasswordDialog(
  BuildContext context,
) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _ChangePasswordDialog(),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();

  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(context).pop(
      _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Set a new password',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PasswordField(
              controller: _password,
              label: 'New password',
              validator: AuthValidators.strongPassword,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();

            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Update'),
        ),
      ],
    );
  }
}
