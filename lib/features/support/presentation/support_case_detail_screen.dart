import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/utils/timestamp.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../../../core/widgets/read_only_notice.dart';
import '../data/support_labels.dart';
import '../data/support_models.dart';
import '../data/support_repository.dart';

/// Read-only support case thread (v50).
///
/// Fetches `GET /api/v1/support/cases/:kind/:id` and renders the case
/// summary + the conversation messages in chronological order. No reply
/// composer — v50 is read-only.
class SupportCaseDetailScreen extends ConsumerWidget {
  const SupportCaseDetailScreen({
    super.key,
    required this.kind,
    required this.id,
  });

  /// Either `'message'` or `'ticket'`. Always taken from a list-tile's
  /// `type` field, never user-typed.
  final String kind;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail =
        ref.watch(supportCaseDetailProvider((kind: kind, id: id)));

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        actions: [
          AppRefreshButton(
            onPressed: () => ref.invalidate(
              supportCaseDetailProvider((kind: kind, id: id)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(
            supportCaseDetailProvider((kind: kind, id: id)),
          ),
          child: detail.when(
            // v71: scrollable loading wrapper for consistent
            // RefreshIndicator behaviour across all states.
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 48),
              children: const [
                AppLoading(message: 'جارٍ تحميل المحادثة...'),
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
                          message: 'تعذّر تحميل المحادثة.',
                          kind: ApiErrorKind.unknown,
                        ),
                  onRetry: () => ref.invalidate(
                    supportCaseDetailProvider((kind: kind, id: id)),
                  ),
                ),
              ],
            ),
            data: (d) => _DetailBody(detail: d),
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});
  final SupportCaseDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    final children = <Widget>[
      _SummaryCard(summary: s),
      const SizedBox(height: 12),
      // v66: explicit read-only notice — there's no composer / reply
      // button on this screen and the user deserves to know why before
      // they hunt for one. v76: now uses the shared ReadOnlyNotice.
      const ReadOnlyNotice(
        message: 'هذه المحادثة للقراءة فقط حالياً.',
      ),
      const SizedBox(height: 12),
      const _SectionHeader(label: 'المحادثة'),
      const SizedBox(height: 8),
    ];
    if (detail.messages.isEmpty) {
      children.add(const AppEmptyState(
        icon: Icons.forum_outlined,
        title: 'لا توجد رسائل بعد.',
      ));
    } else {
      for (final m in detail.messages) {
        children.add(_MessageBubble(message: m));
        children.add(const SizedBox(height: 8));
      }
    }
    children.add(const SizedBox(height: 16));
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final SupportCase summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.subject.isNotEmpty ? summary.subject : '—',
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Chip(
                icon: summary.type == 'ticket'
                    ? Icons.confirmation_number_outlined
                    : Icons.mail_outline,
                label: summary.type == 'ticket' ? 'تذكرة' : 'رسالة',
              ),
              if (summary.status.isNotEmpty)
                _Chip(
                  icon: Icons.flag_outlined,
                  label: SupportLabels.statusLabel(summary.status),
                ),
              if (summary.category != null && summary.category!.isNotEmpty)
                _Chip(
                  icon: Icons.category_outlined,
                  label: SupportLabels.categoryLabel(summary.category!),
                ),
              if (summary.priority != null && summary.priority!.isNotEmpty)
                _Chip(
                  icon: Icons.priority_high_outlined,
                  label: SupportLabels.priorityLabel(summary.priority!),
                ),
              if (summary.relatedDeviceId != null)
                _Chip(
                  icon: Icons.solar_power_outlined,
                  label: 'الجهاز #${summary.relatedDeviceId}',
                ),
            ],
          ),
          if (summary.createdAt != null && summary.createdAt!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _MetaRow(
              label: 'تاريخ الفتح',
              value: formatDateTime(summary.createdAt) ?? '—',
            ),
          ],
          if (summary.lastReplyAt != null &&
              summary.lastReplyAt!.isNotEmpty)
            _MetaRow(
              label: 'آخر رد',
              value: formatDateTime(summary.lastReplyAt) ?? '—',
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final isAdmin = message.senderScope.toLowerCase() == 'admin';
    return AppCard(
      borderColor: isAdmin ? AppTheme.indigoBright : AppTheme.line,
      background: isAdmin ? AppTheme.indigoSoft : AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAdmin
                    ? Icons.support_agent_outlined
                    : Icons.person_outline,
                size: 16,
                color: isAdmin ? AppTheme.indigoPrimary : AppTheme.faintMuted,
              ),
              const SizedBox(width: 6),
              Text(
                isAdmin ? 'الدعم' : 'أنت',
                style: TextStyle(
                  color: isAdmin
                      ? AppTheme.indigoPrimary
                      : AppTheme.faintMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (message.createdAt != null && message.createdAt!.isNotEmpty)
                Text(
                  formatDateTime(message.createdAt) ?? '',
                  style: const TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          if (message.body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message.body,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.ink,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.indigoSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.indigoBright.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.indigoPrimary, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.indigoPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
