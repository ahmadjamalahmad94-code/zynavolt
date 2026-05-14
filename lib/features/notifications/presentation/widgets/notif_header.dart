import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';

/// v102 DS v1 — Notifications screen page header.
///
/// Top-right title "الإشعارات" (with a small unread dot), subtitle
/// "مركز التحكم الذكي لمصادر الطاقة", and a left-anchored circular
/// avatar slot (with a notification dot to nudge the user toward
/// their profile when there's an account-level event).
///
/// The avatar tap target is the only interactive bit — used by the
/// existing flow to open the More / Profile screen. Tap delegated
/// to [onAvatarTap].
class NotifHeader extends StatelessWidget {
  const NotifHeader({
    super.key,
    required this.unreadCount,
    required this.onAvatarTap,
    this.profileHasAlert = false,
  });

  final int unreadCount;
  final VoidCallback onAvatarTap;
  final bool profileHasAlert;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AvatarBadge(
          hasAlert: profileHasAlert,
          onTap: onAvatarTap,
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unreadCount > 0) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: ZynColors.primary500,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Text(
                  'الإشعارات',
                  style: TextStyle(
                    color: ZynColors.ink,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'مركز التحكم الذكي لمصادر الطاقة',
              style: TextStyle(
                color: ZynColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.hasAlert, required this.onTap});

  final bool hasAlert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ZynColors.surface,
                  border: Border.all(color: ZynColors.line, width: 1),
                  boxShadow: ZynShadows.soft(),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 22,
                  color: ZynColors.muted,
                ),
              ),
              if (hasAlert)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: ZynColors.primary500,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ZynColors.surface,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
