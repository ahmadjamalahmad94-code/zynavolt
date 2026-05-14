import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../../loads_recommendations/data/loads_recommendations_models.dart';
import '../../../loads_recommendations/data/loads_recommendations_repository.dart';
import 'loads_list_sheet.dart';

/// v102 DS v1 — "اقتراح الأحمال" sub-strip inside the
/// Suggestions section.
///
/// Pulls `GET /api/mobile/loads/recommendations` via
/// [loadsRecommendationsProvider]. Renders two side-by-side
/// cards:
///   * مسموح الآن — green, lists up to 3 allowed loads as chips,
///     count badge, "اضغط للكل" affordance.
///   * غير مسموح الآن — red, same layout for the denied set.
///
/// Tapping a card opens [LoadsListSheet] with the FULL list for
/// that bucket.
///
/// Async branches handled honestly:
///   * Loading → calm skeleton matching the strip dimensions.
///   * Unavailable (no reading / weather) → compact line under
///     the section header explaining the wait.
///   * Available + zero loads → a single line tile inviting the
///     user to register loads.
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
              onTap: () => _openSheet(context, allowed, allowed: true),
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
              onTap: () => _openSheet(context, denied, allowed: false),
            ),
          ),
        ],
      ),
    );
  }

  /// Format a power total in watts to a compact label. Owner asked
  /// the cards to "show totals briefly" — we render a single
  /// metric per bucket alongside the count badge: "≈ 1.3 kW" when
  /// over 1 kW, "≈ 750 W" otherwise. Empty buckets get an empty
  /// string so the card layout doesn't reserve a useless line.
  String _formatPower(double watts) {
    if (watts <= 0) return '';
    if (watts >= 1000) {
      return '≈ ${(watts / 1000).toStringAsFixed(1)} ك.و';
    }
    return '≈ ${watts.toStringAsFixed(0)} و';
  }

  void _openSheet(BuildContext context, List<LoadItem> items,
      {required bool allowed}) {
    if (items.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ZynColors.surface,
      builder: (_) => LoadsListSheet(items: items, allowed: allowed),
    );
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
    required this.onTap,
  });

  final Color tone;
  final Color toneSoft;
  final IconData icon;
  final String title;
  final List<LoadItem> items;

  /// Compact totals string for this bucket — e.g. "≈ 1.3 ك.و" or
  /// "≈ 700 و". Empty when the bucket has zero items (the card
  /// already says "لا أحمال…" so the subtitle would be redundant).
  final String powerSubtitle;

  final VoidCallback onTap;

  static const int _previewCount = 3;

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
                            style: const TextStyle(
                              color: ZynColors.ink,
                              fontSize: 12.5,
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
                                  fontFeatures:
                                      const [FontFeature.tabularFigures()],
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
                        borderRadius:
                            BorderRadius.circular(ZynRadii.pill),
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
                  Text(
                    title == 'مسموح الآن'
                        ? 'لا أحمال مسموحة الآن.'
                        : 'لا أحمال يُنصح بتأجيلها.',
                    style: const TextStyle(
                      color: ZynColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  )
                else ...[
                  for (final it in preview) ...[
                    _NameChip(text: it.name, tone: tone),
                    const SizedBox(height: 4),
                  ],
                  if (overflow > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '+ $overflow — اضغط للكل',
                        style: TextStyle(
                          color: tone,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else if (items.length <= _previewCount)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        'اضغط للتفاصيل',
                        style: TextStyle(
                          color: ZynColors.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
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
  const _NameChip({required this.text, required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
