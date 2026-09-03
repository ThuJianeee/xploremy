import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../auth/auth_validators.dart';

class ProfileFields extends StatelessWidget {
  const ProfileFields({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.cityController,
    required this.operatorId,
    required this.onOperatorChanged,
    this.enabled = true,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController cityController;
  final String? operatorId;
  final ValueChanged<String?> onOperatorChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: nameController,
          enabled: enabled,
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
          controller: phoneController,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Contact number',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          validator: (value) {
            final phone = value?.trim() ?? '';
            if (phone.isEmpty) return null;
            if (!RegExp(r'^\+?[0-9 \-]{7,15}$').hasMatch(phone)) {
              return 'Enter a valid phone number';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: cityController,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Home city',
            hintText: 'Kuala Lumpur, Johor Bahru, George Town…',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          key: ValueKey(operatorId),
          initialValue: operatorId,
          decoration: const InputDecoration(
            labelText: 'Preferred operator',
            prefixIcon: Icon(Icons.commute_outlined),
          ),
          items: [
            for (final op in Operators.all)
              DropdownMenuItem<String>(
                value: op.id,
                child: Text(op.shortName),
              ),
          ],
          onChanged: enabled ? onOperatorChanged : null,
        ),
      ],
    );
  }
}
