import 'package:flutter/material.dart';

class AuthSuccessScreen extends StatelessWidget {
  const AuthSuccessScreen({
    super.key,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onPressed,
    this.email,
    this.showExpiry = false,
    this.icon = Icons.check_circle_outline,
  });

  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;

  final String? email;
  final bool showExpiry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('XploreMY'),
        automaticallyImplyLeading: false,
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
                  Icon(
                    icon,
                    size: 76,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        email!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (showExpiry) ...[
                    const SizedBox(height: 18),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'This link expires in 5 minutes.',
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onPressed,
                      child: Text(buttonText),
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
}
