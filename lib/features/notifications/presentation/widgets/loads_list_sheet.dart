import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../../loads_recommendations/data/loads_recommendations_models.dart';

/// Mobile-side sanitiser for backend reason strings.
///
/// The Heavy v10.5.x dispatcher emits reasons like
/// "الفائض المتوقع كافٍ (1500 و)" where `و` is the Arabic
/// abbreviation for "واط". The single-letter form is ambiguous
/// under some fonts (it reads as Latin `g`), so we expand it to
/// the full word before rendering. Backend-side fix isn't an
/// option per owner's mobile-only constraint on this pass.
///
/// Public so future widgets that consume the same backend strings
/// can apply the same defensive replacement.
String sanitizeReason(String raw) {
  // ` و)` is the suffix the dispatcher always emits; replacing
  // it keeps any future English-only reason intact.
  return raw.replaceAll(' و)', ' واط)');
}

/// v102 DS v1 — bottom sheet showing the full allow/deny list.
///
/// Opened from the two summary tiles inside the Suggestions
/// section. Title labels the bucket (مسموح الآن / غير مسموح
/// الآن) with the count; the body scrolls every item as a
/// row of name + power + reason. Tone-coloured leading icon
/// per item picks up the bucket's tone (success / danger).
class LoadsListSheet extends StatelessWidget {
  const LoadsListSheet({
    super.key,
    required this.items,
    required this.allowed,
  });

  final List<LoadItem> items;

  /// `true` → "مسموح الآن" green styling. `false` → "غير مسموح
  /// الآن" red styling.
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    final tone = allowed ? ZynColors.success : ZynColors.danger;
    final toneSoft =
        allowed ? ZynColors.successSoft : ZynColors.dangerSoft;
    final icon = allowed
        ? Icons.check_circle_outline_rounded
        : Icons.do_not_disturb_alt_rounded;
    final title = allowed ? 'مسموح الآن' : 'غير مسموح الآن';
    final mq = MediaQuery.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: ZynSpacing.lg,
          right: ZynSpacing.lg,
          bottom: ZynSpacing.lg + mq.viewInsets.bottom,
          top: ZynSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: tone, size: 18),
                ),
                const SizedBox(width: ZynSpacing.md),
                Text(
                  title,
                  style: const TextStyle(
                    color: ZynColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(width: ZynSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius:
                        BorderRadius.circular(ZynRadii.pill),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZynSpacing.lg),
            if (items.isEmpty)
              _EmptyLine(tone: tone, allowed: allowed)
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: mq.size.height * 0.55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: ZynSpacing.sm),
                  itemBuilder: (_, i) => _LoadRow(
                    item: items[i],
                    tone: tone,
                    toneSoft: toneSoft,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadRow extends StatelessWidget {
  const _LoadRow({
    required this.item,
    required this.tone,
    required this.toneSoft,
  });

  final LoadItem item;
  final Color tone;
  final Color toneSoft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: toneSoft.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(ZynRadii.tile),
        border: Border.all(
          color: tone.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bolt_rounded, color: tone, size: 16),
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name.isEmpty ? '—' : item.name,
                        style: const TextStyle(
                          color: ZynColors.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${item.powerW.toStringAsFixed(0)} واط',
                      style: TextStyle(
                        color: tone,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures:
                            const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (item.reason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sanitizeReason(item.reason),
                    style: const TextStyle(
                      color: ZynColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.tone, required this.allowed});

  final Color tone;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.tile),
        border: Border.all(color: ZynColors.line, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            allowed
                ? Icons.do_not_disturb_alt_rounded
                : Icons.check_circle_outline_rounded,
            color: tone,
            size: 18,
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Text(
              allowed
                  ? 'لا توجد أحمال مسموحة في هذه اللحظة.'
                  : 'لا توجد أحمال يُنصح بتأجيلها الآن.',
              style: const TextStyle(
                color: ZynColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
