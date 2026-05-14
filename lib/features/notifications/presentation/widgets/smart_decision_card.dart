import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../../../core/utils/backend_time.dart';
import '../../../insights/data/insights_models.dart';
import '../../../insights/data/insights_repository.dart';

/// v102 DS v1 — top-of-section card for "اقتراحات ذكية".
///
/// Renders the system's current decision pulled straight from
/// `GET /api/v1/devices/<id>/insights` (the same `smart_engine`
/// output the web dashboard uses — no mobile-side heuristics, no
/// mock data). The card carries:
///
///   * a small "القرار الحالي للنظام" eyebrow + tone-tinted icon
///   * the backend's `headline` (e.g. "🟢 مطمئن") as the title
///   * the backend's `detail` (smart_warning + smart_recommendation)
///     as the body
///   * a footer line with "آخر تحديث" and the localised time
///
/// Behaviour:
///   * Insights loading → skeleton card (subtle, single line).
///   * Insights unavailable (no reading / no weather) → compact
///     "القرار غير متوفر الآن" card with the backend's `reason`
///     translated to Arabic copy.
///   * Insights available but `energyAdvice` empty → same fallback.
class SmartDecisionCard extends ConsumerWidget {
  const SmartDecisionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(insightsProvider);
    return async.when(
      loading: _LoadingShell.new,
      error: (_, _) => const _UnavailableShell(
        message: 'تعذّر تحميل القرار الحالي للنظام.',
      ),
      data: (snap) {
        if (snap == null) {
          return const _UnavailableShell(
            message: 'اختَر جهازاً لعرض القرار الحالي.',
          );
        }
        if (!snap.available) {
          return _UnavailableShell(message: _reasonCopy(snap.reason));
        }
        final advice = snap.energyAdvice;
        if (advice == null || advice.isEmpty) {
          return const _UnavailableShell(
            message: 'القرار الحالي غير جاهز بعد.',
          );
        }
        return _DecisionBody(
          advice: advice,
          generatedAt: snap.generatedAt,
        );
      },
    );
  }

  String _reasonCopy(String? reason) {
    switch (reason) {
      case 'reading_unavailable':
        return 'لا توجد قراءة حديثة بعد لاستنتاج القرار.';
      case 'station_coords_unavailable':
        return 'بيانات الموقع للجهاز غير مكتملة — لا يمكن استنتاج قرار طقس.';
      case 'weather_unreachable':
        return 'تعذّر الوصول إلى مزود الطقس الآن. حاول لاحقاً.';
      default:
        return 'القرار الحالي غير متوفر الآن.';
    }
  }
}

class _DecisionBody extends StatelessWidget {
  const _DecisionBody({required this.advice, required this.generatedAt});

  final InsightsEnergyAdvice advice;
  final String generatedAt;

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(advice.level);
    final time = formatBackendHm(generatedAt) ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(
          color: tone.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: ZynShadows.soft(tint: tone),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: tone,
                  size: 18,
                ),
              ),
              const SizedBox(width: ZynSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'القرار الحالي للنظام',
                      style: TextStyle(
                        color: ZynColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      advice.headline.isEmpty ? '—' : advice.headline,
                      style: TextStyle(
                        color: tone,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (advice.detail.isNotEmpty) ...[
            const SizedBox(height: ZynSpacing.sm),
            // Owner-tuned: drop the nested tinted box (it read as
            // "box inside box" against the white card). The detail
            // now sits inline below the headline, with a hair of
            // start-edge tone-colour to keep the visual link to
            // the card's accent without a heavy container.
            Container(
              padding: const EdgeInsetsDirectional.fromSTEB(
                10,
                2,
                0,
                2,
              ),
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(
                    color: tone.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                advice.detail,
                style: const TextStyle(
                  color: ZynColors.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.55,
                ),
              ),
            ),
          ],
          if (time.isNotEmpty) ...[
            const SizedBox(height: ZynSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: ZynColors.faint,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'آخر تحديث',
                  style: const TextStyle(
                    color: ZynColors.faint,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: const TextStyle(
                    color: ZynColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _toneFor(String level) {
    switch (level) {
      case 'good':
        return ZynColors.success;
      case 'caution':
        return ZynColors.warning;
      case 'warning':
        return ZynColors.warning;
      case 'critical':
        return ZynColors.danger;
      default:
        return ZynColors.accent;
    }
  }
}

class _UnavailableShell extends StatelessWidget {
  const _UnavailableShell({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ZynColors.primary50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_empty_rounded,
              color: ZynColors.primary500,
              size: 18,
            ),
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'القرار الحالي للنظام',
                  style: TextStyle(
                    color: ZynColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: ZynColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
    return Container(
      height: 84,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ZynColors.primary50,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 8,
                  decoration: BoxDecoration(
                    color: ZynColors.primary50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 10,
                  decoration: BoxDecoration(
                    color: ZynColors.primary50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
