import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../data/support_labels.dart';
import '../data/support_models.dart';
import '../data/support_repository.dart';

/// Read-only Support inbox (v50).
///
/// Lists the user's existing support cases (internal mail threads +
/// tickets) from the backend's `mobile_support_api` blueprint. v50 ships
/// list + read-only thread detail. Reply / open / close are intentionally
/// not wired here — backend endpoints exist but are out of scope for the
/// foundation commit.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(supportCasesProvider);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        title: const Text('الدعم'),
        actions: [
          AppRefreshButton(
            onPressed: () => ref.invalidate(supportCasesProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(supportCasesProvider),
          child: page.when(
            // v71: scrollable loading wrapper for consistent
            // RefreshIndicator behaviour across all states.
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 48),
              children: const [
                AppLoading(message: 'جارٍ تحميل طلبات الدعم...'),
              ],
            ),
            error: (err, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                AppErrorState(
                  error: err is ApiException
                      ? err
                      : ApiException(
                          message: 'تعذّر تحميل طلبات الدعم.',
                          kind: ApiErrorKind.unknown,
                        ),
                  onRetry: () => ref.invalidate(supportCasesProvider),
                ),
              ],
            ),
            data: (data) {
              if (data.items.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: const [
                    AppEmptyState(
                      icon: Icons.support_agent_outlined,
                      title: 'لا توجد طلبات دعم بعد',
                      subtitle: 'ستظهر هنا أي محادثات أو تذاكر مفتوحة مع الدعم.',
                    ),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: data.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _SupportCaseTile(
                  caseSummary: data.items[i],
                  onTap: () => context.push(
                    AppRoutes.supportCase(
                      data.items[i].type,
                      data.items[i].id,
                    ),
                  ),
                ),
              );
            },
          ),
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
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.indigoSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  caseSummary.type == 'ticket'
                      ? Icons.confirmation_number_outlined
                      : Icons.mail_outline,
                  color: AppTheme.indigoPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
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
                              color: AppTheme.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(status: caseSummary.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
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
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left,
                  color: AppTheme.faintMuted, size: 20),
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
      tone = AppTheme.success;
      label = 'مفتوحة';
    } else if (s.contains('pending') || s.contains('wait')) {
      tone = AppTheme.warning;
      label = 'قيد المعالجة';
    } else if (s.contains('closed') || s.contains('resolv')) {
      tone = AppTheme.faintMuted;
      label = 'مغلقة';
    } else {
      tone = AppTheme.faintMuted;
      label = status.isNotEmpty ? status : '—';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Text(
        // v73: bumped fontSize 10.5 → 11 for readability.
        label,
        style: TextStyle(
          color: tone,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
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
        Icon(icon, color: AppTheme.faintMuted, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.faintMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
