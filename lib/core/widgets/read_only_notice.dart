import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// Calm "للقراءة فقط" notice (v76).
///
/// A subtle indigo-tinted banner that signals the surrounding screen is
/// view-only. Use sparingly — it should clarify, not warn. Default copy
/// reads `هذه الصفحة للعرض فقط حالياً.` — caller can override `message`
/// for context-specific wording.
class ReadOnlyNotice extends StatelessWidget {
  const ReadOnlyNotice({
    super.key,
    this.message = 'هذه الصفحة للعرض فقط حالياً.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.indigoSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: AppTheme.indigoBright.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline,
              color: AppTheme.indigoPrimary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.indigoPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
