import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../../loads_recommendations/data/loads_recommendations_models.dart';
import '../../../loads_recommendations/data/loads_recommendations_repository.dart';
import 'loads_list_sheet.dart';

/// v102 DS v1 — "اقتراح الأحمال" sub-strip.
///
/// Pulls `GET /api/mobile/loads/recommendations` via
/// [loadsRecommendationsProvider]. Renders ONE of three layouts
/// based on the bucket counts:
///
///   * Mixed (both allowed and denied non-empty) → two
///     side-by-side cards.
///   * All allowed (denied empty) → single full-width "كل
///     الأحمال مسموحة الآن" card.
///   * All denied (allowed empty) → single full-width "لا أحمال
///     مسموحة الآن" card.
///
/// This avoids the awkward "empty bucket next to a full bucket"
/// state where the empty side reads as broken UI.
///
/// Tap on any card → opens [LoadsListSheet] with the FULL list
/// for that bucket.
class LoadsRecommendationsStrip extends ConsumerWidget {
  const LoadsRecommendationsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(loadsRecommendationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SubHeader(),
        const SizedBox(height: ZynSpacing.sm),
        async.when(
          loading: _LoadingShell.new,
          error: (_, _) => const _UnavailableLine(
            message: 'تعذّر تحميل اقتراح الأحمال.',
          ),
          data: (snap) {
            if (snap == null) {
              return const _UnavailableLine(
                message: 'اختَر جهازاً لعرض اقتراح الأحمال.',
              );
            }
            if (!snap.available) {
              return _UnavailableLine(message: _reasonCopy(snap.reason));
            }
            if (snap.items.isEmpty) {
              return const _UnavailableLine(
                message: 'لا توجد أحمال مسجّلة لحسابك بعد.',
              );
            }
            return _StripBody(snap: snap);
          },
        ),
      ],
    );
  }

  String _reasonCopy(String? reason) {
    switch (reason) {
      case 'reading_unavailable':
        return 'لا توجد قراءة حديثة بعد لاستنتاج اقتراح الأحمال.';
      case 'station_coords_unavailable':
        return 'بيانات الموقع للجهاز غير مكتملة.';
      case 'weather_unreachable':
        return 'تعذّر الوصول إلى مزود الطقس الآن.';
      case 'no_active_device':
        return 'لا يوجد جهاز نشط على الحساب.';
      default:
        return 'اقتراح الأحمال غير متوفر الآن.';
    }
  }
}

class _SubHeader extends StatelessWidget {
  const _SubHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZynSpacing.xs,
        vertical: ZynSpacing.xs,
      ),
      child: Row(
        children: const [
          Icon(
            Icons.electrical_services_rounded,
            color: ZynColors.accent,
            size: 14,
          ),
          SizedBox(width: 6),
          Text(
            'اقتراح الأحمال',
            style: TextStyle(
              color: ZynColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StripBody extends StatelessWidget {
  const _StripBody({required this.snap});

  final LoadsRecommendationsSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final allowed = snap.allowed;
    final denied = snap.denied;
    final allAllowed = denied.isEmpty && allowed.isNotEmpty;
    final allDenied = allowed.isEmpty && denied.isNotEmpty;

    if (allAllowed) {
      return _BucketCard(
        tone: ZynColors.success,
        toneSoft: ZynColors.successSoft,
        icon: Icons.check_circle_outline_rounded,
        title: 'كل الأحمال مسموحة الآن',
        items: allowed,
        powerSubtitle: _formatPower(snap.totals.allowedPowerW),
        wide: true,
        onTap: () =>
            _openSheet(context, allowed, allowed: true),
      );
    }

    if (allDenied) {
      return _BucketCard(
        tone: ZynColors.danger,
        toneSoft: ZynColors.dangerSoft,
        icon: Icons.do_not_disturb_alt_rounded,
        title: 'لا أحمال مسموحة الآن',
        items: denied,
        powerSubtitle: _formatPower(snap.totals.deniedPowerW),
        wide: true,
        onTap: () =>
            _openSheet(context, denied, allowed: false),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _BucketCard(
              tone: ZynColors.success,
              toneSoft: ZynColors.successSoft,
              icon: Icons.check_circle_outline_rounded,
              title: 'مسموح الآن',
              items: allowed,
              powerSubtitle: _formatPower(snap.totals.allowedPowerW),
              wide: false,
              onTap: () =>
                  _openSheet(context, allowed, allowed: true),
            ),
          ),
          const SizedBox(width: ZynSpacing.sm),
          Expanded(
            child: _BucketCard(
              tone: ZynColors.danger,
              toneSoft: ZynColors.dangerSoft,
              icon: Icons.do_not_disturb_alt_rounded,
              title: 'غير مسموح الآن',
              items: denied,
              powerSubtitle: _formatPower(snap.totals.deniedPowerW),
              wide: false,
              onTap: () =>
                  _openSheet(context, denied, allowed: false),
            ),
          ),
        ],
      ),
    );
  }

  void _openSheet(
    BuildContext context,
    List<LoadItem> items, {
    required bool allowed,
  }) {
    if (items.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ZynColors.surface,
      builder: (_) => LoadsListSheet(items: items, allowed: allowed),
    );
  }

  /// Owner-tuned: never use the ambiguous `و` glyph (mistaken for
  /// Latin `g`). Full Arabic words read clearly under any font:
  ///   * ≥ 1000 W → "≈ 1.3 كيلوواط"
  ///   * > 0      → "≈ 40 واط"
  ///   * 0        → empty (the card already says "لا أحمال…")
  String _formatPower(double watts) {
    if (watts <= 0) return '';
    if (watts >= 1000) {
      return '≈ ${(watts / 1000).toStringAsFixed(1)} كيلوواط';
    }
    return '≈ ${watts.toStringAsFixed(0)} واط';
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.tone,
    required this.toneSoft,
    required this.icon,
    required this.title,
    required this.items,
    required this.powerSubtitle,
    required this.wide,
    required this.onTap,
  });

  final Color tone;
  final Color toneSoft;
  final IconData icon;
  final String title;
  final List<LoadItem> items;
  final String powerSubtitle;

  /// `true` when this card is the only one on screen (the empty
  /// sibling was hidden). Lets the layout show more preview chips
  /// since there's more horizontal room.
  final bool wide;

  final VoidCallback onTap;

  /// Preview chip count differs between wide and compact layouts.
  /// In wide mode the user sees roughly twice as much before the
  /// "عرض الكل" footer.
  int get _previewCount => wide ? 6 : 3;

  @override
  Widget build(BuildContext context) {
    final preview = items.take(_previewCount).toList(growable: false);
    final overflow = items.length - preview.length;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.card),
      child: InkWell(
        onTap: items.isEmpty ? null : onTap,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        child: Ink(
          decoration: BoxDecoration(
            color: toneSoft.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(ZynRadii.card),
            border: Border.all(
              color: tone.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: tone, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: ZynColors.ink,
                              fontSize: wide ? 14 : 12.5,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (powerSubtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                powerSubtitle,
                                style: TextStyle(
                                  color: tone,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: tone,
                        borderRadius: BorderRadius.circular(ZynRadii.pill),
                      ),
                      child: Text(
                        '${items.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZynSpacing.sm),
                if (items.isEmpty)
                  // Reachable only in degenerate cases — both
                  // `wide` layouts handle their own empty copy
                  // upstream by switching cards.
                  Text(
                    'لا أحمال في هذه الفئة الآن.',
                    style: const TextStyle(
                      color: ZynColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  )
                else if (wide)
                  // Wide mode: chips lay out in a Wrap so two
                  // short names share a row.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final it in preview)
                        _NameChip(text: it.name, tone: tone, compact: true),
                    ],
                  )
                else
                  // Compact mode: one chip per row, stacked.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final it in preview) ...[
                        _NameChip(text: it.name, tone: tone, compact: false),
                        const SizedBox(height: 4),
                      ],
                    ],
                  ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    overflow > 0
                        ? 'عرض الكل ($overflow أخرى)'
                        : 'عرض التفاصيل',
                    style: TextStyle(
                      color: tone,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NameChip extends StatelessWidget {
  const _NameChip({
    required this.text,
    required this.tone,
    required this.compact,
  });

  final String text;
  final Color tone;

  /// `true` → chip sizes to its content (used in wide Wrap layout
  /// so multiple chips can share a row).
  /// `false` → chip fills the column width (compact stacked
  /// layout).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? null : double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.tight),
        border: Border.all(
          color: tone.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: ZynColors.ink,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _UnavailableLine extends StatelessWidget {
  const _UnavailableLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_empty_rounded,
            color: ZynColors.muted,
            size: 16,
          ),
          const SizedBox(width: ZynSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ZynColors.muted,
                fontSize: 12.5,
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

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _SkeletonCard(tone: ZynColors.success)),
          const SizedBox(width: ZynSpacing.sm),
          Expanded(child: _SkeletonCard(tone: ZynColors.danger)),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.tone});

  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(
          color: tone.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 80,
            height: 10,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: 22,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}
