import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

/// Splash held until [AppSessionController.restore] resolves the auth phase.
/// The router redirect handles transitioning out — this screen is just paint.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.indigoPrimary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.wb_sunny_outlined,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Zynavolt',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'منصة إدارة الطاقة الشمسية',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
