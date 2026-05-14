import 'package:flutter/material.dart';

import '../design/zyn_tokens.dart';

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
        color: ZynColors.primary50,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(
          color: ZynColors.primary500.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline,
              color: ZynColors.primary700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ZynColors.primary700,
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
