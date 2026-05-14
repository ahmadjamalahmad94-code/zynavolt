import 'package:flutter/material.dart';

import '../design/zyn_tokens.dart';

/// Centralised loading state. Defaults to light text + bright
/// primary500 spinner so it reads cleanly on the v102 dark navy
/// page backdrop. Pass `onDark: false` when rendering inside a
/// white card on a light surface.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.message, this.onDark = true});

  final String? message;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final messageColor =
        onDark ? Colors.white.withValues(alpha: 0.78) : ZynColors.muted;
    final spinnerColor =
        onDark ? ZynColors.primary500 : ZynColors.primary700;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: spinnerColor,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 14),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: messageColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
