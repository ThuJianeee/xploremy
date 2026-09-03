import 'package:flutter/material.dart';

import '../../../widgets/password_field.dart';
import '../../auth/auth_validators.dart';

Future<String?> showChangePasswordDialog(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final password = TextEditingController();
  final confirm = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Set a new password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PasswordField(
                controller: password,
                label: 'New password',
                validator: AuthValidators.strongPassword,
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: confirm,
                label: 'Confirm password',
                prefixIcon: Icons.lock_reset_outlined,
                validator: (value) => AuthValidators.confirmPassword(
                  value,
                  password.text,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, password.text);
              }
            },
            child: const Text('Update'),
          ),
        ],
      );
    },
  );

  password.dispose();
  confirm.dispose();
  return result;
}
