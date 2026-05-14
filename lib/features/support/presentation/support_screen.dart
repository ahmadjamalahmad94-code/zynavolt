import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/support_labels.dart';
import '../data/support_models.dart';
import '../data/support_repository.dart';

/// v102 DS v1 — Support inbox.
///
/// Lists internal mail threads + tickets from
/// `mobile_support_api`. FAB pushes the create-case form; tapping
/// a row pushes the case-detail thread. List rendering and data
/// layer are unchanged — only the visual shell was rebuilt on the
/// DS tokens.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(supportCasesProvider);

    return ZynScreen(
      hero: ZynPageHero(
        title: 'الدعم',
        subtitle: 'محادثاتك وتذاكرك مع فريق الدعم.',
        trailing: ZynHeroActionButton(
          icon: Icons.refresh_rounded,
          tooltip: 'تحديث',
          onPressed: () => ref.invalidate(supportCasesProvider),
        ),
      ),
      floatingActionButton: _NewCaseFab(
        onTap: () => context.push(AppRoutes.supportCreate),
      ),
      padding: const EdgeInsets.fromLTRB(
        ZynSpacing.lg,
        ZynSpacing.lg,
        ZynSpacing.lg,
        96,
      ),
      child: page.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: AppLoading(message: 'جارٍ تحميل طلبات الدعم...'),
        ),
        error: (err, _) => AppErrorState(
          error: err is ApiException
              ? err
              : ApiException(
                  message: 'تعذّر تحميل طلبات الدعم.',
                  kind: ApiErrorKind.unknown,
                ),
          onRetry: () => ref.invalidate(supportCasesProvider),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return const ZynEmptyState(
              icon: Icons.support_agent_outlined,
              title: 'لا توجد طلبات دعم بعد',
              subtitle:
                  'ستظهر هنا أي محادثات أو تذاكر مفتوحة مع الدعم.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < data.items.length; i++) ...[
                _SupportCaseTile(
                  caseSummary: data.items[i],
                  onTap: () => context.push(
                    AppRoutes.supportCase(
                      data.items[i].type,
                      data.items[i].id,
                    ),
                  ),
                ),
                if (i < data.items.length - 1)
                  const SizedBox(height: ZynSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NewCaseFab extends StatelessWidget {
  const _NewCaseFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZynRadii.pill),
        boxShadow: [
          BoxShadow(
            color: ZynColors.primary500.withValues(alpha: 0.40),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: onTap,
        backgroundColor: ZynColors.primary700,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'طلب جديد',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZynRadii.pill),
        ),
      ),
    );
  }
}

class _SupportCaseTile extends StatelessWidget {
  const _SupportCaseTile({required this.caseSummary, required this.onTap});

  final SupportCase caseSummary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        child: Ink(
          decoration: BoxDecoration(
            color: ZynColors.surface,
            borderRadius: BorderRadius.circular(ZynRadii.card),
            border: Border.all(color: ZynColors.line, width: 1),
            boxShadow: ZynShadows.soft(),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient:
                      ZynGradients.iconFill(ZynColors.primary500),
                  borderRadius: BorderRadius.circular(ZynRadii.inner),
                  boxShadow: ZynShadows.iconGlow(ZynColors.primary500),
                ),
                child: Icon(
                  caseSummary.type == 'ticket'
                      ? Icons.confirmation_number_outlined
                      : Icons.mail_outline_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: ZynSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            caseSummary.subject.isNotEmpty
                                ? caseSummary.subject
                                : '—',
                            style: const TextStyle(
                              color: ZynColors.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(status: caseSummary.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _MetaChip(
                          icon: caseSummary.type == 'ticket'
                              ? Icons.label_outline
                              : Icons.alternate_email,
                          label: _kindLabel(caseSummary.type),
                        ),
                        if (caseSummary.category != null &&
                            caseSummary.category!.isNotEmpty)
                          _MetaChip(
                            icon: Icons.category_outlined,
                            label: SupportLabels.categoryLabel(
                                caseSummary.category!),
                          ),
                        if (caseSummary.priority != null &&
                            caseSummary.priority!.isNotEmpty)
                          _MetaChip(
                            icon: Icons.priority_high_outlined,
                            label: SupportLabels.priorityLabel(
                                caseSummary.priority!),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_left_rounded,
                color: ZynColors.muted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _kindLabel(String type) {
    switch (type) {
      case 'ticket':
        return 'تذكرة';
      case 'message':
        return 'رسالة';
      default:
        return type;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final Color tone;
    final String label;
    if (s.contains('open') || s.contains('new')) {
      tone = ZynColors.success;
      label = 'مفتوحة';
    } else if (s.contains('pending') || s.contains('wait')) {
      tone = ZynColors.warning;
      label = 'قيد المعالجة';
    } else if (s.contains('closed') || s.contains('resolv')) {
      tone = ZynColors.muted;
      label = 'مغلقة';
    } else {
      tone = ZynColors.muted;
      label = status.isNotEmpty ? status : '—';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZynRadii.pill),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: ZynColors.muted, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: ZynColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
