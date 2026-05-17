import 'package:flutter/material.dart';

import '../../../core/design/zyn_tokens.dart';

/// v100 — Splash, built on the design-system dark hero gradient.
///
/// Held while [AppSessionController.restore] resolves auth phase.
/// The router redirect transitions out; this screen is just paint.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: ZynColors.heroGradient),
        child: Stack(
          children: [
            // Two radial blooms — top-left cyan, bottom-right violet —
            // so the splash reads as "lit glass slab" not a flat plane.
            Positioned(
              top: -120,
              left: -80,
              child: _Bloom(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                size: 360,
              ),
            ),
            Positioned(
              bottom: -100,
              right: -80,
              child: _Bloom(
                color: ZynColors.violet.withValues(alpha: 0.30),
                size: 320,
              ),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo — the brand mark already ships with its
                    // own navy rounded-square background and orange
                    // arc, so we render it as-is and just sit it on
                    // a soft amber bloom that picks up the bolt's
                    // accent. No gradient ring, no clip — the asset
                    // is the identity.
                    Container(
                      width: 132,
                      height: 132,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFFA227).withValues(alpha: 0.32),
                            blurRadius: 36,
                            offset: const Offset(0, 14),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/branding/zynavolt_logo.png',
                        width: 132,
                        height: 132,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.wb_sunny_outlined,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'ZYNAVOLT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'منصة إدارة الطاقة الشمسية',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Spinner — subtle, on-brand.
                    Container(
                      width: 32,
                      height: 32,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                          width: 1,
                        ),
                      ),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bloom extends StatelessWidget {
  const _Bloom({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}
