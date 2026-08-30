import 'package:flutter/material.dart';

import '../core/theme.dart';

/// XploreMY wordmark used on the auth screens.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, required this.tagline});

  final String tagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: AppTheme.hibiscus,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.route_outlined,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            const Text(
              'XploreMY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          tagline,
          style: const TextStyle(
            color: Color(0xCCFFFFFF),
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
