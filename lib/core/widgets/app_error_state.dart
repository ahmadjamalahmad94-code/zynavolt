import 'package:flutter/material.dart';

import '../design/zyn_tokens.dart';
import '../api/api_exception.dart';

/// Unified error widget. Pass any [ApiException] and the widget picks an
/// appropriate icon, tone, and retry affordance.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.retryLabel,
  });

  final ApiException error;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final iconData = _iconFor(error.kind);
    final tone = _toneFor(error.kind);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(iconData, size: 28, color: tone),
            ),
            const SizedBox(height: 14),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ZynColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.55,
              ),
            ),
            if (error.code != null) ...[
              const SizedBox(height: 6),
              Text(
                error.code!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ZynColors.muted,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onRetry,
                child: Text(retryLabel ?? 'إعادة المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _toneFor(ApiErrorKind kind) {
  switch (kind) {
    case ApiErrorKind.network:
    case ApiErrorKind.timeout:
      return ZynColors.warning;
    case ApiErrorKind.unauthorized:
    case ApiErrorKind.forbidden:
      return ZynColors.danger;
    case ApiErrorKind.validation:
    case ApiErrorKind.conflict:
      return ZynColors.warning;
    case ApiErrorKind.rateLimited:
      return ZynColors.warning;
    case ApiErrorKind.server:
    case ApiErrorKind.decode:
    case ApiErrorKind.unknown:
      return ZynColors.danger;
    case ApiErrorKind.notFound:
      return ZynColors.muted;
    case ApiErrorKind.cancelled:
      return ZynColors.muted;
  }
}

IconData _iconFor(ApiErrorKind kind) {
  switch (kind) {
    case ApiErrorKind.network:
    case ApiErrorKind.timeout:
      return Icons.wifi_off_outlined;
    case ApiErrorKind.unauthorized:
      return Icons.lock_outline;
    case ApiErrorKind.forbidden:
      return Icons.block_outlined;
    case ApiErrorKind.notFound:
      return Icons.search_off_outlined;
    case ApiErrorKind.validation:
      return Icons.error_outline;
    case ApiErrorKind.conflict:
      return Icons.warning_amber_outlined;
    case ApiErrorKind.rateLimited:
      return Icons.hourglass_bottom_outlined;
    case ApiErrorKind.server:
    case ApiErrorKind.decode:
    case ApiErrorKind.unknown:
      return Icons.cloud_off_outlined;
    case ApiErrorKind.cancelled:
      return Icons.do_disturb_alt_outlined;
  }
}
