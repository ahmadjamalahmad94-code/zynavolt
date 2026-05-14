import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/utils/timestamp.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/support_labels.dart';
import '../data/support_models.dart';
import '../data/support_repository.dart';
import 'attachment_draft_strip.dart';

/// v102 DS v1 — Support case thread.
///
/// Local AsyncValue + 12 s polling drives the screen so admin
/// replies arrive without manual refresh. Pull-to-refresh and
/// the in-line composer continue to work; only the visuals were
/// rebuilt against DS v1 tokens (no logic changes).
class SupportCaseDetailScreen extends ConsumerStatefulWidget {
  const SupportCaseDetailScreen({
    super.key,
    required this.kind,
    required this.id,
  });

  final String kind;
  final int id;

  @override
  ConsumerState<SupportCaseDetailScreen> createState() =>
      _SupportCaseDetailScreenState();
}

class _SupportCaseDetailScreenState
    extends ConsumerState<SupportCaseDetailScreen> {
  static const Duration _pollInterval = Duration(seconds: 12);
  static const double _nearBottomThreshold = 120;

  AsyncValue<SupportCaseDetail> _state = const AsyncValue.loading();
  Timer? _pollTimer;
  final ScrollController _scrollController = ScrollController();

  int _highestSeenMessageId = 0;
  bool _hasUnseenIncoming = false;

  @override
  void initState() {
    super.initState();
    _initialLoad();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    try {
      final detail = await ref
          .read(supportRepositoryProvider)
          .fetch(widget.kind, widget.id);
      if (!mounted) return;
      setState(() {
        _state = AsyncValue.data(detail);
        _highestSeenMessageId = _maxMessageId(detail);
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _state = AsyncValue.error(e, st));
    }
  }

  Future<void> _poll({required bool silent}) async {
    if (!mounted) return;
    try {
      final detail = await ref
          .read(supportRepositoryProvider)
          .fetch(widget.kind, widget.id);
      if (!mounted) return;
      _consumeFreshDetail(detail);
    } catch (e, st) {
      if (silent) return;
      if (!mounted) return;
      setState(() => _state = AsyncValue.error(e, st));
    }
  }

  void _consumeFreshDetail(SupportCaseDetail detail) {
    final newHighest = _maxMessageId(detail);
    final brandNewIncoming = newHighest > _highestSeenMessageId;
    final wasNearBottom = _isNearBottom();
    setState(() => _state = AsyncValue.data(detail));
    if (!brandNewIncoming) return;
    if (wasNearBottom) {
      _highestSeenMessageId = newHighest;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      setState(() => _hasUnseenIncoming = true);
    }
  }

  int _maxMessageId(SupportCaseDetail detail) {
    var max = 0;
    for (final m in detail.messages) {
      if (m.id > max) max = m.id;
    }
    return max;
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return true;
    return position.maxScrollExtent - position.pixels <= _nearBottomThreshold;
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
    if (_hasUnseenIncoming) {
      setState(() {
        _hasUnseenIncoming = false;
        final data = _state.valueOrNull;
        if (data != null) {
          _highestSeenMessageId = _maxMessageId(data);
        }
      });
    }
  }

  Future<void> _onLocalReplySent() async {
    await _poll(silent: false);
    if (!mounted) return;
    final data = _state.valueOrNull;
    if (data != null) {
      _highestSeenMessageId = _maxMessageId(data);
    }
    setState(() => _hasUnseenIncoming = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _manualRefresh() async {
    await _poll(silent: false);
  }

  @override
  Widget build(BuildContext context) {
    return ZynScreen(
      hero: ZynPageHero(
        title: 'تفاصيل الطلب',
        subtitle: 'محادثتك مع فريق الدعم.',
        trailing: ZynHeroActionButton(
          icon: Icons.refresh_rounded,
          tooltip: 'تحديث',
          onPressed: _manualRefresh,
        ),
      ),
      scrollController: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        ZynSpacing.lg,
        ZynSpacing.lg,
        ZynSpacing.lg,
        96,
      ),
      floatingActionButton: _hasUnseenIncoming
          ? Container(
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
                onPressed: _scrollToBottom,
                backgroundColor: ZynColors.primary700,
                foregroundColor: Colors.white,
                elevation: 0,
                icon: const Icon(Icons.arrow_downward_rounded),
                label: const Text(
                  'رسائل جديدة',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ZynRadii.pill),
                ),
              ),
            )
          : null,
      child: _state.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: AppLoading(message: 'جارٍ تحميل المحادثة...'),
        ),
        error: (err, _) => AppErrorState(
          error: err is ApiException
              ? err
              : ApiException(
                  message: 'تعذّر تحميل المحادثة.',
                  kind: ApiErrorKind.unknown,
                ),
          onRetry: _manualRefresh,
        ),
        data: (d) => _DetailBody(
          kind: widget.kind,
          id: widget.id,
          detail: d,
          onMessageSent: _onLocalReplySent,
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.kind,
    required this.id,
    required this.detail,
    required this.onMessageSent,
  });

  final String kind;
  final int id;
  final SupportCaseDetail detail;
  final Future<void> Function() onMessageSent;

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    final isClosed = s.status.toLowerCase() == 'closed' ||
        s.status.toLowerCase() == 'resolved' ||
        s.status.toLowerCase() == 'cancelled' ||
        s.status.toLowerCase() == 'canceled';

    final children = <Widget>[
      _SummaryCard(summary: s),
      const SizedBox(height: ZynSpacing.md),
      const ZynSectionHeader(
        label: 'المحادثة',
        icon: Icons.forum_outlined,
      ),
      const SizedBox(height: ZynSpacing.sm),
    ];
    if (detail.messages.isEmpty) {
      children.add(const ZynEmptyState(
        icon: Icons.forum_outlined,
        title: 'لا توجد رسائل بعد.',
      ));
    } else {
      for (final m in detail.messages) {
        children.add(KeyedSubtree(
          key: ValueKey<int>(m.id),
          child: _MessageBubble(message: m),
        ));
        children.add(const SizedBox(height: ZynSpacing.sm));
      }
    }
    children.add(const SizedBox(height: ZynSpacing.md));
    children.add(_ReplyComposer(
      kind: kind,
      id: id,
      isClosed: isClosed,
      onSent: onMessageSent,
    ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _ReplyComposer extends ConsumerStatefulWidget {
  const _ReplyComposer({
    required this.kind,
    required this.id,
    required this.isClosed,
    required this.onSent,
  });

  final String kind;
  final int id;
  final bool isClosed;
  final Future<void> Function() onSent;

  @override
  ConsumerState<_ReplyComposer> createState() => _ReplyComposerState();
}

class _ReplyComposerState extends ConsumerState<_ReplyComposer> {
  final _controller = TextEditingController();
  bool _sending = false;
  List<AttachmentDraft> _drafts = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(supportRepositoryProvider).reply(
            kind: widget.kind,
            id: widget.id,
            body: body,
            attachments: _drafts.map((d) => d.toSpec()).toList(),
          );
      if (!mounted) return;
      _controller.clear();
      final summary = buildRejectionSummary(
        result.rejectedAttachments,
        savedCount: result.savedAttachments.length,
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: summary != null
              ? const Duration(seconds: 5)
              : const Duration(seconds: 2),
          content: Text(summary ?? 'تم إرسال الرد.'),
        ));
      setState(() => _drafts = const []);
      await widget.onSent();
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('تعذّر إرسال الرد: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isClosed) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ZynColors.surfaceAlt,
          borderRadius: BorderRadius.circular(ZynRadii.card),
          border: Border.all(color: ZynColors.line, width: 1),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.lock_outline,
              color: ZynColors.muted,
              size: 17,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'هذا الطلب مغلق ولا يمكن إضافة ردود جديدة.',
                style: TextStyle(
                  color: ZynColors.muted,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'إضافة رد',
            style: TextStyle(
              color: ZynColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'اكتب رسالتك هنا...',
            ),
          ),
          const SizedBox(height: ZynSpacing.sm),
          AttachmentDraftStrip(
            drafts: _drafts,
            enabled: !_sending,
            onChanged: (next) => setState(() => _drafts = next),
          ),
          const SizedBox(height: ZynSpacing.md),
          ZynButton(
            label: 'إرسال',
            icon: Icons.send_rounded,
            busy: _sending,
            onTap: _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final SupportCase summary;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.subject.isNotEmpty ? summary.subject : '—',
            style: const TextStyle(
              color: ZynColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: ZynSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _SummaryChip(
                icon: summary.type == 'ticket'
                    ? Icons.confirmation_number_outlined
                    : Icons.mail_outline,
                label: summary.type == 'ticket' ? 'تذكرة' : 'رسالة',
              ),
              if (summary.status.isNotEmpty)
                _SummaryChip(
                  icon: Icons.flag_outlined,
                  label: SupportLabels.statusLabel(summary.status),
                ),
              if (summary.category != null && summary.category!.isNotEmpty)
                _SummaryChip(
                  icon: Icons.category_outlined,
                  label: SupportLabels.categoryLabel(summary.category!),
                ),
              if (summary.priority != null && summary.priority!.isNotEmpty)
                _SummaryChip(
                  icon: Icons.priority_high_outlined,
                  label: SupportLabels.priorityLabel(summary.priority!),
                ),
              if (summary.relatedDeviceId != null)
                _SummaryChip(
                  icon: Icons.solar_power_outlined,
                  label: 'الجهاز #${summary.relatedDeviceId}',
                ),
            ],
          ),
          if (summary.createdAt != null && summary.createdAt!.isNotEmpty) ...[
            const SizedBox(height: ZynSpacing.sm),
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

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: ZynColors.primary500.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZynRadii.pill),
        border: Border.all(
          color: ZynColors.primary500.withValues(alpha: 0.30),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ZynColors.primary700, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: ZynColors.primary700,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isAdmin ? ZynColors.primary50 : ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(
          color: isAdmin
              ? ZynColors.primary500.withValues(alpha: 0.30)
              : ZynColors.line,
          width: 1,
        ),
        boxShadow: ZynShadows.soft(tint: isAdmin ? ZynColors.primary500 : null),
      ),
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
                color: isAdmin ? ZynColors.primary700 : ZynColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                isAdmin ? 'الدعم' : 'أنت',
                style: TextStyle(
                  color: isAdmin ? ZynColors.primary700 : ZynColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (message.createdAt != null && message.createdAt!.isNotEmpty)
                Text(
                  formatDateTime(message.createdAt) ?? '',
                  style: const TextStyle(
                    color: ZynColors.muted,
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          if (message.body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message.body,
              style: const TextStyle(
                color: ZynColors.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                height: 1.6,
              ),
            ),
          ],
          if (message.attachments.isNotEmpty) ...[
            const SizedBox(height: ZynSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final attachment in message.attachments) ...[
                  _AttachmentRow(attachment: attachment),
                  if (attachment != message.attachments.last)
                    const SizedBox(height: 6),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentRow extends ConsumerStatefulWidget {
  const _AttachmentRow({required this.attachment});

  final SupportAttachment attachment;

  @override
  ConsumerState<_AttachmentRow> createState() => _AttachmentRowState();
}

class _AttachmentRowState extends ConsumerState<_AttachmentRow> {
  bool _busy = false;

  Future<void> _onTap() async {
    if (_busy) return;
    final attachment = widget.attachment;
    final download = attachment.downloadUrl.trim();
    if (download.isEmpty) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref
          .read(supportRepositoryProvider)
          .downloadAttachment(download);

      final cache = await getTemporaryDirectory();
      final safeName = _safeFilename(attachment);
      final file = File('${cache.path}/support_${attachment.id}_$safeName');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path);
      if (!mounted) return;
      switch (result.type) {
        case ResultType.done:
          break;
        case ResultType.noAppToOpen:
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              duration: Duration(seconds: 3),
              content: Text(
                'لا يوجد تطبيق على الجهاز قادر على فتح هذا النوع من الملفات.',
              ),
            ));
          break;
        case ResultType.fileNotFound:
        case ResultType.permissionDenied:
        case ResultType.error:
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              duration: const Duration(seconds: 3),
              content: Text(
                result.message.isNotEmpty
                    ? 'تعذّر فتح الملف: ${result.message}'
                    : 'تعذّر فتح الملف.',
              ),
            ));
          break;
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(_arabicMessageForError(e)),
        ));
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 3),
          content: Text('تعذّر تنزيل الملف: $e'),
        ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.attachment;
    final icon = _iconForAttachment(attachment);
    final sizeLabel = attachment.humanSize;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.inner),
      child: InkWell(
        onTap: _busy ? null : _onTap,
        borderRadius: BorderRadius.circular(ZynRadii.inner),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: ZynColors.surface,
            borderRadius: BorderRadius.circular(ZynRadii.inner),
            border: Border.all(color: ZynColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ZynColors.primary50,
                  borderRadius: BorderRadius.circular(ZynRadii.tight),
                ),
                child: Icon(icon, color: ZynColors.primary700, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ZynColors.ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (sizeLabel.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        sizeLabel,
                        style: const TextStyle(
                          color: ZynColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                const Icon(
                  Icons.download_outlined,
                  size: 18,
                  color: ZynColors.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _arabicMessageForError(ApiException e) {
  switch (e.code) {
    case 'attachment_storage_missing':
      return 'تم رفع هذا الملف قبل تحديث الخادم ولم يعد متاحًا. اطلب '
          'من الدعم إعادة رفعه داخل المحادثة.';
    case 'attachment_not_found':
    case 'support_case_not_found':
      return 'لم يعد هذا المرفق متاحًا.';
    default:
      return e.message;
  }
}

IconData _iconForAttachment(SupportAttachment a) {
  final mime = a.contentType.toLowerCase();
  if (mime.startsWith('image/')) return Icons.image_outlined;
  if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
  if (mime.contains('zip') || mime.contains('compressed')) {
    return Icons.folder_zip_outlined;
  }
  if (mime.contains('sheet') ||
      mime.contains('excel') ||
      mime.contains('csv')) {
    return Icons.table_chart_outlined;
  }
  if (mime.contains('word') || mime.contains('document')) {
    return Icons.description_outlined;
  }
  final lower = a.originalFilename.toLowerCase();
  if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
  if (lower.endsWith('.zip')) return Icons.folder_zip_outlined;
  if (lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.gif')) {
    return Icons.image_outlined;
  }
  if (lower.endsWith('.csv') ||
      lower.endsWith('.xls') ||
      lower.endsWith('.xlsx')) {
    return Icons.table_chart_outlined;
  }
  if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
    return Icons.description_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

String _safeFilename(SupportAttachment a) {
  final raw = a.originalFilename.trim();
  final fallback = 'attachment_${a.id}';
  if (raw.isEmpty) return fallback;
  final cleaned = raw.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
  if (cleaned.isEmpty) return fallback;
  return cleaned.length > 80
      ? cleaned.substring(cleaned.length - 80)
      : cleaned;
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
                color: ZynColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: ZynColors.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
