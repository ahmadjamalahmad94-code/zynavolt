/// v102 DS v1 — mobile plan-change preview/confirm screen.
///
/// Mirrors the web `subscriber_plan_change_preview.html` flow:
///   1. Fetch `/api/mobile/account/plan-change/preview?plan_id=…`.
///   2. Render the policy-aware narrative (downgrade / upgrade /
///      lateral).
///   3. Let the subscriber commit to a scenario via
///      `/api/mobile/account/plan-change/confirm`.
///   4. For `payment_required` outcomes, call
///      `/api/mobile/account/plan-change/checkout` and launch the
///      Stripe-hosted URL via `url_launcher` (external browser).
///   5. For `applied` outcomes, invalidate the account snapshot so
///      the calling screen refreshes in-place.
///
/// Policy correctness is enforced by the backend (downgrade cannot
/// produce a refund). The UI hides the forbidden choice so the
/// subscriber never sees a path that would be refused.
library plan_change_preview_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/account_models.dart';
import '../data/account_repository.dart';
import '../data/plan_change_models.dart';

class PlanChangePreviewScreen extends ConsumerStatefulWidget {
  const PlanChangePreviewScreen({super.key, required this.targetPlan});

  final AvailablePlan targetPlan;

  @override
  ConsumerState<PlanChangePreviewScreen> createState() =>
      _PlanChangePreviewScreenState();
}

class _PlanChangePreviewScreenState
    extends ConsumerState<PlanChangePreviewScreen> {
  late Future<PlanChangePreview> _previewFuture;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _previewFuture = _load();
  }

  Future<PlanChangePreview> _load() {
    final repo = ref.read(accountRepositoryProvider);
    final planId = widget.targetPlan.id;
    if (planId == null) {
      throw ApiException(
        message: 'الخطة المطلوبة غير صالحة.',
        kind: ApiErrorKind.validation,
        code: 'plan_id_invalid',
      );
    }
    return repo.previewPlanChange(planId: planId);
  }

  Future<void> _refresh() async {
    setState(() {
      _previewFuture = _load();
    });
    await _previewFuture;
  }

  Future<void> _onConfirm(PlanChangePreview preview, String mode) async {
    if (_submitting) return;
    final confirmed = await _showConfirmDialog(preview, mode);
    if (confirmed != true) return;
    final planId = widget.targetPlan.id;
    if (planId == null) return;
    setState(() => _submitting = true);
    try {
      final repo = ref.read(accountRepositoryProvider);
      final result = await repo.confirmPlanChange(planId: planId, mode: mode);
      if (!mounted) return;
      if (result.needsPayment && result.caseId != null) {
        await _handlePaymentRequired(result);
      } else if (result.isApplied) {
        _showSuccessAndPop('تم تطبيق تغيير الخطة بنجاح.');
      } else if (result.isBlocked) {
        _showError(_arabicBlockedReason(result.blockedReason));
      } else {
        _showError('استجابة غير متوقّعة من الخادم.');
      }
    } on ApiException catch (exc) {
      if (!mounted) return;
      _showError(_arabicApiError(exc));
    } catch (_) {
      if (!mounted) return;
      _showError('حدث خطأ غير متوقّع. الرجاء المحاولة مجدداً.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handlePaymentRequired(PlanChangeConfirmResult result) async {
    final repo = ref.read(accountRepositoryProvider);
    try {
      final session = await repo.createCheckoutSession(caseId: result.caseId!);
      if (!mounted) return;
      final uri = Uri.tryParse(session.url);
      if (uri == null) {
        _showError('تعذّر فتح صفحة الدفع.');
        return;
      }
      final launched = await launchUrl(uri,
          mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!launched) {
        _showError('تعذّر فتح صفحة الدفع.');
        return;
      }
      _showSuccessAndPop(
        'تم فتح صفحة الدفع. أكمل الدفع لإتمام تغيير الخطة.',
      );
    } on ApiException catch (exc) {
      if (!mounted) return;
      _showError(_arabicApiError(exc));
    }
  }

  void _showSuccessAndPop(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: ZynColors.success,
        content: Text(message),
        duration: const Duration(seconds: 4),
      ));
    Navigator.of(context).pop(true);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: ZynColors.danger,
        content: Text(message),
      ));
  }

  String _arabicApiError(ApiException exc) {
    switch (exc.code) {
      case 'auth_required':
        return 'انتهت الجلسة. الرجاء تسجيل الدخول مجدداً.';
      case 'plan_id_invalid':
      case 'plan_id_required':
        return 'الخطة المطلوبة غير صالحة.';
      case 'no_active_subscription':
        return 'لا يوجد اشتراك فعّال.';
      case 'target_plan_unavailable':
        return 'الخطة المطلوبة غير متاحة.';
      case 'same_plan_already_active':
        return 'أنت على هذه الخطة بالفعل.';
      case 'downgrade_same_duration_not_allowed':
        return 'النزول إلى خطة أرخص لا يُرجع مبالغ — استخدم خيار التحويل إلى أيام أكثر.';
      case 'unknown_mode':
        return 'وضع التسعير غير معروف.';
      case 'no_pending_invoice':
        return 'لا يوجد مبلغ مستحق على هذا الطلب.';
      case 'case_not_pending_payment':
        return 'هذا الطلب ليس بانتظار الدفع.';
      case 'stripe_not_ready':
        return 'خدمة الدفع غير مهيّأة. الرجاء التواصل مع الدعم.';
      case 'stripe_error':
        return 'تعذّر إنشاء جلسة الدفع. حاول مجدداً.';
      case 'internal_error':
        return 'حدث خطأ غير متوقّع. الرجاء المحاولة مجدداً.';
      default:
        return exc.message.isNotEmpty
            ? exc.message
            : 'تعذّر إتمام العملية.';
    }
  }

  String _arabicBlockedReason(String? reason) {
    return _arabicApiError(ApiException(
      message: '',
      kind: ApiErrorKind.validation,
      code: reason,
    ));
  }

  Future<bool?> _showConfirmDialog(
      PlanChangePreview preview, String mode) async {
    final scenario =
        mode == 'same_duration' ? preview.sameDuration : preview.reducedDays;
    final amountLine = scenario.amount > 0
        ? 'سيتم إنشاء طلب دفع بمبلغ ${scenario.amount.toStringAsFixed(2)} ${preview.currency}.'
        : 'لا يوجد مبلغ مستحق.';
    final daysLine =
        'الأيام بعد التغيير: ${scenario.targetDays} يوماً على ${preview.targetPlanLabel}.';
    final extraWarning =
        (preview.policyKind == 'upgrade' && mode == 'reduced_days')
            ? 'ملاحظة: ستحصل على أيام أقل من رصيدك الحالي.'
            : null;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد تغيير الخطة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(daysLine),
            const SizedBox(height: 8),
            Text(amountLine),
            if (extraWarning != null) ...[
              const SizedBox(height: 8),
              Text(
                extraWarning,
                style: const TextStyle(
                  color: ZynColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ZynScreen(
      hero: const ZynPageHero(
        title: 'تغيير الخطة',
        subtitle: 'تفاصيل التحويل وأثره على الأيام والمدفوعات.',
      ),
      child: FutureBuilder<PlanChangePreview>(
        future: _previewFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: AppLoading(message: 'جاري حساب الأيام...'),
            );
          }
          if (snap.hasError) {
            final exc = snap.error;
            final apiExc = exc is ApiException
                ? exc
                : ApiException(
                    message: 'تعذّر تحميل تفاصيل تغيير الخطة.',
                    kind: ApiErrorKind.unknown,
                  );
            return AppErrorState(error: apiExc, onRetry: _refresh);
          }
          final preview = snap.data!;
          if (preview.isBlocked) {
            return _BlockedView(
              arabicMessage: _arabicBlockedReason(preview.blockedReason),
            );
          }
          return _PreviewBody(
            preview: preview,
            submitting: _submitting,
            onConfirm: (mode) => _onConfirm(preview, mode),
          );
        },
      ),
    );
  }
}

// ─── Body ────────────────────────────────────────────────────────

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.preview,
    required this.submitting,
    required this.onConfirm,
  });

  final PlanChangePreview preview;
  final bool submitting;
  final ValueChanged<String> onConfirm;

  @override
  Widget build(BuildContext context) {
    final policy = preview.policyKind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PolicyHero(policy: policy),
        const SizedBox(height: ZynSpacing.md),
        _DecisionExplainer(preview: preview),
        const SizedBox(height: ZynSpacing.md),
        _SituationSummary(preview: preview),
        const SizedBox(height: ZynSpacing.md),
        if (policy == 'downgrade') ...[
          const _IneligibleSameDurationCard(),
          const SizedBox(height: ZynSpacing.md),
          _ScenarioCard(
            preview: preview,
            scenario: preview.reducedDays,
            isPrimary: true,
            ctaLabel: 'تحويل إلى أيام أكثر',
            ctaColor: ZynColors.success,
            submitting: submitting,
            onConfirm: () => onConfirm('reduced_days'),
            title: 'تحويل قيمتي إلى أيام أكثر',
            tag: 'الموصى به',
            description:
                'تتحوّل قيمتك المتبقّية (${preview.reducedDays.currentRemainingValue.toStringAsFixed(2)} ${preview.currency}) '
                'إلى ${preview.reducedDays.targetDays} يوماً على الخطة الأرخص. '
                'لا تتحرّك أي مبالغ ولا يتم إرجاع شيء.',
          ),
        ] else if (policy == 'upgrade') ...[
          _ScenarioCard(
            preview: preview,
            scenario: preview.sameDuration,
            isPrimary: false,
            ctaLabel: preview.sameDuration.amount > 0
                ? 'إنشاء طلب دفع للفرق'
                : 'تطبيق الآن',
            ctaColor: ZynColors.warning,
            submitting: submitting,
            onConfirm: () => onConfirm('same_duration'),
            title: 'الخيار أ — إبقاء أيامي مع دفع الفرق',
            tag: 'الخيار أ',
            description:
                'تحتفظ بـ ${preview.remainingDays} يوماً المتبقّية، وتدفع فرق السعر '
                '(${preview.sameDuration.amount.toStringAsFixed(2)} ${preview.currency}) '
                'لإتمام التحويل. الخطة تُطبَّق بعد الدفع.',
          ),
          const SizedBox(height: ZynSpacing.md),
          _ScenarioCard(
            preview: preview,
            scenario: preview.reducedDays,
            isPrimary: true,
            ctaLabel: 'تطبيق مع أيام أقل',
            ctaColor: ZynColors.success,
            submitting: submitting,
            onConfirm: () => onConfirm('reduced_days'),
            title: 'الخيار ب — أيام أقل بدون دفع إضافي',
            tag: 'الخيار ب',
            description:
                'تُحفظ قيمتك المتبقّية (${preview.reducedDays.currentRemainingValue.toStringAsFixed(2)} ${preview.currency}) '
                'ويُعاد تسعيرها على الخطة الأعلى، فتحصل على ${preview.reducedDays.targetDays} يوماً دون أي مبلغ إضافي.',
          ),
        ] else ...[
          _ScenarioCard(
            preview: preview,
            scenario: preview.sameDuration,
            isPrimary: true,
            ctaLabel: 'تطبيق التحويل',
            ctaColor: ZynColors.primary500,
            submitting: submitting,
            onConfirm: () => onConfirm('same_duration'),
            title: 'تحويل مكافئ',
            tag: 'مباشر',
            description:
                'الخطتان متقاربتان في السعر اليومي — يتم التحويل مباشرة بدون دفع وبدون تعديل في الأيام.',
          ),
        ],
        const SizedBox(height: ZynSpacing.lg),
        const _HelpHint(),
      ],
    );
  }
}

class _PolicyHero extends StatelessWidget {
  const _PolicyHero({required this.policy});

  final String policy;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, subtitle) = switch (policy) {
      'downgrade' => (
          ZynColors.success,
          Icons.south_rounded,
          'الانتقال إلى خطة أرخص — أيام أكثر',
          'تُحوَّل قيمتك المتبقّية إلى أيام إضافية على الخطة الجديدة. لا يتم إرجاع أي مبلغ.'
        ),
      'upgrade' => (
          ZynColors.warning,
          Icons.north_rounded,
          'الانتقال إلى خطة أعلى — اختر طريقة الانتقال',
          'احتفظ بأيامك وادفع الفرق، أو خذ أياماً أقل دون أي مبلغ إضافي.'
        ),
      _ => (
          ZynColors.primary500,
          Icons.swap_horiz_rounded,
          'تغيير الخطة',
          'تحويل مباشر بدون دفع وبدون تعديل في الأيام.'
        ),
    };

    return Container(
      decoration: BoxDecoration(
        gradient: ZynGradients.glossSurface(tint: color),
        borderRadius: BorderRadius.circular(ZynRadii.xl),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: ZynShadows.soft(tint: color),
      ),
      padding: const EdgeInsets.all(ZynSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: ZynGradients.iconFill(color),
              borderRadius: BorderRadius.circular(ZynRadii.inner),
              boxShadow: ZynShadows.iconGlow(color),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZynColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZynColors.inkSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    height: 1.55,
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

class _DecisionExplainer extends StatelessWidget {
  const _DecisionExplainer({required this.preview});

  final PlanChangePreview preview;

  @override
  Widget build(BuildContext context) {
    final policy = preview.policyKind;
    final color = policy == 'downgrade'
        ? ZynColors.success
        : policy == 'upgrade'
            ? ZynColors.warning
            : ZynColors.primary500;
    final perDay =
        preview.reducedDays.extra.targetPerDayPrice?.toStringAsFixed(4) ?? '—';
    final remainingValue =
        preview.sameDuration.currentRemainingValue.toStringAsFixed(2);
    final hint = policy == 'downgrade'
        ? 'لديك $remainingValue ${preview.currency} قيمة متبقّية. '
            'الخطة الجديدة تكلّفك $perDay ${preview.currency} فقط في اليوم، '
            'فينتج عن قسمة قيمتك على هذا السعر أيام أكثر. '
            'لهذا تحصل على ${preview.reducedDays.targetDays} يوماً.'
        : policy == 'upgrade'
            ? 'الخطة الجديدة تكلّف $perDay ${preview.currency} في اليوم — '
                'أكثر من السعر اليومي لخطتك الحالية. لو احتفظت بأيامك ستدفع الفرق، '
                'أو تأخذ أياماً أقل دون دفع. حتى الخطة ذات السعر الكلي الأقل قد تكون "أغلى في اليوم" لو كانت دورتها أقصر.'
            : 'الخطتان متقاربتان في السعر اليومي، فالتحويل مباشر.';

    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'كيف يتم حساب الأيام',
                  style: TextStyle(
                    color: ZynColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hint,
                  style: const TextStyle(
                    color: ZynColors.inkSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    height: 1.65,
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

class _SituationSummary extends StatelessWidget {
  const _SituationSummary({required this.preview});

  final PlanChangePreview preview;

  @override
  Widget build(BuildContext context) {
    final s = preview.sameDuration;
    return _Card(
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: ZynSpacing.sm,
        crossAxisSpacing: ZynSpacing.sm,
        childAspectRatio: 2.0,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _KpiTile(
            label: 'الخطة الحالية',
            value: preview.currentPlanLabel,
            sub:
                '${s.currentPlanPrice.toStringAsFixed(2)} ${preview.currency} / ${s.cycleDaysCurrent} يوم',
          ),
          _KpiTile(
            label: 'الخطة المطلوبة',
            value: preview.targetPlanLabel,
            sub:
                '${s.targetPlanPrice.toStringAsFixed(2)} ${preview.currency} / ${s.cycleDaysTarget} يوم',
          ),
          _KpiTile(
            label: 'الأيام المتبقّية',
            value: '${preview.remainingDays}',
            sub: 'على الخطة الحالية',
          ),
          _KpiTile(
            label: 'قيمة المتبقّي',
            value:
                '${s.currentRemainingValue.toStringAsFixed(2)} ${preview.currency}',
            sub: 'محسوبة بالتناسب',
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile(
      {required this.label, required this.value, required this.sub});

  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ZynColors.surfaceAlt,
        borderRadius: BorderRadius.circular(ZynRadii.tile),
        border: Border.all(color: ZynColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ZynColors.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: ZynColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            sub,
            style: const TextStyle(
              color: ZynColors.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.preview,
    required this.scenario,
    required this.isPrimary,
    required this.ctaLabel,
    required this.ctaColor,
    required this.submitting,
    required this.onConfirm,
    required this.title,
    required this.tag,
    required this.description,
  });

  final PlanChangePreview preview;
  final PlanChangeScenario scenario;
  final bool isPrimary;
  final String ctaLabel;
  final Color ctaColor;
  final bool submitting;
  final VoidCallback onConfirm;
  final String title;
  final String tag;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: ZynColors.surface,
            borderRadius: BorderRadius.circular(ZynRadii.xl),
            border: Border.all(
              color: isPrimary
                  ? ctaColor.withValues(alpha: 0.45)
                  : ZynColors.line,
              width: isPrimary ? 1.5 : 1,
            ),
            boxShadow:
                isPrimary ? ZynShadows.med(tint: ctaColor) : ZynShadows.soft(),
          ),
          padding: const EdgeInsets.fromLTRB(
            ZynSpacing.lg,
            ZynSpacing.lg,
            ZynSpacing.lg,
            ZynSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ZynColors.ink,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  color: ZynColors.inkSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: ZynSpacing.md),
              _ScenarioFacts(scenario: scenario, preview: preview),
              const SizedBox(height: ZynSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ctaColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ZynRadii.inner),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    elevation: 0,
                  ),
                  onPressed: submitting ? null : onConfirm,
                  child: submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(ctaLabel),
                ),
              ),
            ],
          ),
        ),
        if (isPrimary)
          Positioned(
            top: -10,
            right: 18,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ctaColor,
                borderRadius: BorderRadius.circular(ZynRadii.pill),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ScenarioFacts extends StatelessWidget {
  const _ScenarioFacts({required this.scenario, required this.preview});

  final PlanChangeScenario scenario;
  final PlanChangePreview preview;

  @override
  Widget build(BuildContext context) {
    final rows = <List<String>>[
      ['الأيام المتبقّية', '${scenario.remainingDays}'],
      ['الأيام بعد التغيير', '${scenario.targetDays}'],
      [
        'قيمة المتبقّي',
        '${scenario.currentRemainingValue.toStringAsFixed(2)} ${preview.currency}',
      ],
    ];
    rows.add([
      'المبلغ المستحق',
      scenario.amount > 0.001
          ? '+${scenario.amount.toStringAsFixed(2)} ${preview.currency}'
          : '0.00 ${preview.currency}',
    ]);
    return Container(
      decoration: BoxDecoration(
        color: ZynColors.surfaceAlt,
        borderRadius: BorderRadius.circular(ZynRadii.tile),
        border: Border.all(color: ZynColors.line),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r[0],
                      style: const TextStyle(
                        color: ZynColors.inkSoft,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    r[1],
                    style: TextStyle(
                      color: r[0] == 'المبلغ المستحق'
                          ? (scenario.amount > 0
                              ? ZynColors.warning
                              : ZynColors.success)
                          : ZynColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
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

class _IneligibleSameDurationCard extends StatelessWidget {
  const _IneligibleSameDurationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZynSpacing.md),
      decoration: BoxDecoration(
        color: ZynColors.surfaceAlt,
        borderRadius: BorderRadius.circular(ZynRadii.tile),
        border: Border.all(color: ZynColors.line),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'خيار غير متاح: نفس الأيام مع رصيد',
            style: TextStyle(
              color: ZynColors.muted,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'هذا المسار غير مُتاح للنزول إلى خطة أرخص. '
            'بدلاً من إرجاع المبلغ، تُحوَّل قيمتك المتبقّية إلى أيام إضافية على الخطة الجديدة (الخيار أدناه).',
            style: TextStyle(
              color: ZynColors.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpHint extends StatelessWidget {
  const _HelpHint();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'لست متأكداً؟ تواصل مع الدعم قبل التأكيد — الفريق يرحب بمساعدتك.',
      style: TextStyle(
        color: ZynColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _BlockedView extends StatelessWidget {
  const _BlockedView({required this.arabicMessage});

  final String arabicMessage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZynSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ZynColors.muted.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline,
                color: ZynColors.muted,
                size: 36,
              ),
            ),
            const SizedBox(height: ZynSpacing.md),
            Text(
              arabicMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ZynColors.ink,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
            const SizedBox(height: ZynSpacing.lg),
            ZynButton(
              label: 'العودة',
              variant: ZynButtonVariant.secondary,
              expand: false,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ZynSpacing.lg,
        ZynSpacing.md,
        ZynSpacing.lg,
        ZynSpacing.md,
      ),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.soft(),
      ),
      child: child,
    );
  }
}
