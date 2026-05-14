import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';

/// v102 DS v1 — page header for "الطاقة والطقس".
///
/// Single centred title + a pill-shaped subtitle row underneath
/// that names the active device, mirroring the reference design.
/// The device name is passed in so the header doesn't need to
/// know about Riverpod — the screen owns the wiring.
class WeatherHeader extends StatelessWidget {
  const WeatherHeader({super.key, required this.deviceName});

  final String deviceName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Text(
            'الطاقة والطقس',
            style: TextStyle(
              color: ZynColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: ZynSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZynSpacing.md,
            vertical: ZynSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: ZynColors.primary50,
            borderRadius: BorderRadius.circular(ZynRadii.pill),
            border: Border.all(
              color: ZynColors.primary500.withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_outlined,
                color: ZynColors.primary700,
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  deviceName.isEmpty
                      ? 'حالة الطقس الحالية'
                      : 'حالة الطقس الحالية لجهاز: $deviceName',
                  style: const TextStyle(
                    color: ZynColors.primary700,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
