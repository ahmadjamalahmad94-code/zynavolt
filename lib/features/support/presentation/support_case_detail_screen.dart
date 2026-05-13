import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/utils/timestamp.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../data/support_labels.dart';
import '../data/support_models.dart';
import '../data/support_repository.dart';
import 'attachment_draft_strip.dart';

/// Support case thread (v88 + v90b).
///
/// Fetches `GET /api/v1/support/cases/:kind/:id` and renders the case
/// summary + the conversation messages. v88 added a reply composer that
/// posts to `/cases/:kind/:id/reply`.
///
/// v90b switches the screen to **local AsyncValue state + Timer-based
/// polling** so admin replies appear without manual refresh:
///   * Initial fetch on mount.
///   * Silent re-fetch every 12 s while the screen is visible.
///   * Pull-to-refresh still works (and surfaces errors).
///   * After a successful mobile reply, we re-fetch immediately and
///     scroll to the bottom.
///   * Poll errors are silent (the previously-rendered thread stays).
///
/// The previous `supportCaseDetailProvider` is no longer watched by
/// this screen — we drive everything from local state to keep poll
/// failures from flickering the UI into the error path.
class SupportCaseDetailScreen extends ConsumerStatefulWidget {
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
  ConsumerState<SupportCaseDetailScreen> createState() =>
      _SupportCaseDetailScreenState();
}

class _SupportCaseDetailScreenState
    extends ConsumerState<SupportCaseDetailScreen> {
  /// Polling cadence. Short enough that admin replies arrive within
  /// roughly one "blink," long enough to keep mobile data sane.
  static const Duration _pollInterval = Duration(seconds: 12);

  /// Threshold (pixels from end) within which we consider the user
  /// "near the bottom" — new messages auto-scroll here.
  static const double _nearBottomThreshold = 120;

  AsyncValue<SupportCaseDetail> _state = const AsyncValue.loading();
  Timer? _pollTimer;
  final ScrollController _scrollController = ScrollController();

  /// Highest message-id we have shown to the user. New messages with an
  /// id greater than this trigger the "new messages" UX. Used instead of
  /// list length so duplicates and reordering don't cause false positives.
  int _highestSeenMessageId = 0;

  /// Shown when new messages arrive and the user is NOT near the bottom.
  /// Tapping it scrolls to bottom and clears itself.
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

  /// Quietly re-fetches the thread. When `silent` is true (auto-poll),
  /// fetch errors are ignored so the user isn't punished for transient
  /// network blips while the screen is open. Pull-to-refresh / retry
  /// pass `silent: false` so errors do surface.
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

  /// Decide whether to auto-scroll or surface the "رسائل جديدة" chip
  /// when fresh data arrives.
  void _consumeFreshDetail(SupportCaseDetail detail) {
    final newHighest = _maxMessageId(detail);
    final brandNewIncoming = newHighest > _highestSeenMessageId;
    final wasNearBottom = _isNearBottom();
    setState(() => _state = AsyncValue.data(detail));
    if (!brandNewIncoming) return;
    if (wasNearBottom) {
      _highestSeenMessageId = newHighest;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom());
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
    return position.maxScrollExtent - position.pixels <=
        _nearBottomThreshold;
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

  /// Called by the reply composer after a successful POST. We refresh
  /// the thread and snap to the bottom so the user sees their reply.
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
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        actions: [
          AppRefreshButton(onPressed: _manualRefresh),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _manualRefresh,
          child: _state.when(
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
                  onRetry: _manualRefresh,
                ),
              ],
            ),
            data: (d) => _DetailBody(
              kind: widget.kind,
              id: widget.id,
              detail: d,
              scrollController: _scrollController,
              onMessageSent: _onLocalReplySent,
            ),
          ),
        ),
      ),
      floatingActionButton: _hasUnseenIncoming
          ? FloatingActionButton.extended(
              onPressed: _scrollToBottom,
              backgroundColor: AppTheme.indigoPrimary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.arrow_downward),
              label: const Text('رسائل جديدة'),
            )
          : null,
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.kind,
    required this.id,
    required this.detail,
    required this.scrollController,
    required this.onMessageSent,
  });

  final String kind;
  final int id;
  final SupportCaseDetail detail;
  final ScrollController scrollController;
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
        // v90b: stable key per message id so the ListView can reuse
        // bubbles between polls and Flutter doesn't redraw the entire
        // list when one new message lands at the end.
        children.add(KeyedSubtree(
          key: ValueKey<int>(m.id),
          child: _MessageBubble(message: m),
        ));
        children.add(const SizedBox(height: 8));
      }
    }
    children.add(const SizedBox(height: 16));
    children.add(_ReplyComposer(
      kind: kind,
      id: id,
      isClosed: isClosed,
      onSent: onMessageSent,
    ));
    children.add(const SizedBox(height: 24));
    return ListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
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

  /// v90b: invoked by the composer after a successful reply. The parent
  /// screen uses this to re-fetch the thread locally and scroll to the
  /// bottom — replaces the old `ref.invalidate(provider)` round-trip
  /// path so the screen's polling controller stays in charge.
  final Future<void> Function() onSent;

  @override
  ConsumerState<_ReplyComposer> createState() => _ReplyComposerState();
}

class _ReplyComposerState extends ConsumerState<_ReplyComposer> {
  final _controller = TextEditingController();
  bool _sending = false;
  // v72: drafted attachments for THIS reply. Cleared on success so
  // the strip is empty for the next reply on the same thread.
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
      // v72: surface backend rejections honestly. The reply itself
      // posted — we never block the thread refresh on rejected files.
      final summary = buildRejectionSummary(
        result.rejectedAttachments,
        savedCount: result.savedAttachments.length,
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration:
              summary != null ? const Duration(seconds: 5) : const Duration(seconds: 2),
          content: Text(summary ?? 'تم إرسال الرد.'),
        ));
      setState(() => _drafts = const []);
      // Trigger the screen's local refresh + auto-scroll-to-bottom.
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
        ..showSnackBar(
          SnackBar(content: Text('تعذّر إرسال الرد: $e')),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isClosed) {
      return AppCard(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        background: AppTheme.softBg,
        child: Row(
          children: const [
            Icon(Icons.lock_outline,
                color: AppTheme.faintMuted, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'هذا الطلب مغلق ولا يمكن إضافة ردود جديدة.',
                style: TextStyle(
                  color: AppTheme.faintMuted,
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

    return AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'إضافة رد',
            style: TextStyle(
              color: AppTheme.ink,
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
          const SizedBox(height: 10),
          // v72: optional attachments for this reply. The picker
          // strip is hidden mid-send so a second pick doesn't
          // race with the in-flight upload.
          AttachmentDraftStrip(
            drafts: _drafts,
            enabled: !_sending,
            onChanged: (next) => setState(() => _drafts = next),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: AppTheme.formControlHeight + 4,
            child: FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, size: 18),
              label: const Text('إرسال'),
            ),
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
          // v69: read-only attachment chips. Tap → download via the
          // existing bearer-auth Dio client into the app cache, then
          // hand off to the OS viewer. We never launch the bearer-
          // gated URL externally — the OS browser doesn't carry the
          // mobile session.
          if (message.attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
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

/// v69: one attachment row inside a message bubble. Tap triggers a
/// download (bearer-auth Dio) → write to the app cache → OS open.
/// All three steps surface honest errors; storage_missing (HTTP 410)
/// gets a dedicated calm Arabic message.
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

      // Write to a per-attachment temp file inside the app's cache
      // directory. Including the attachment id in the filename keeps
      // a stable on-disk key (re-opening the same attachment hits
      // the same path) while a sanitized original_filename preserves
      // the extension so the OS viewer routes correctly.
      final cache = await getTemporaryDirectory();
      final safeName = _safeFilename(attachment);
      final file = File('${cache.path}/support_${attachment.id}_$safeName');
      await file.writeAsBytes(bytes, flush: true);

      // Hand off to the OS. `open_filex` returns a result that
      // distinguishes "no viewer installed" from a permission error,
      // so we can surface a more helpful message in those cases.
      final result = await OpenFilex.open(file.path);
      if (!mounted) return;
      switch (result.type) {
        case ResultType.done:
          // Success — the OS viewer is now showing the file. No snackbar.
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
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _busy ? null : _onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.indigoSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.indigoPrimary, size: 16),
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
                        color: AppTheme.ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (sizeLabel.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        sizeLabel,
                        style: const TextStyle(
                          color: AppTheme.faintMuted,
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
                  color: AppTheme.faintMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Map the backend's stable `code` onto calm Arabic copy. The v68
/// download endpoint can return:
///   * 410 `attachment_storage_missing` — file gone after redeploy.
///   * 404 `support_case_not_found` / `attachment_not_found` — either
///     the case isn't on this user or the attachment doesn't belong
///     to this case. We surface a single calm message either way.
///   * 401 — auth, surfaced verbatim from `ApiException.message`
///     (the api_client's Arabic default is already user-friendly).
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

/// Best-effort generic icon based on the attachment's mime type or
/// filename extension. Falls back to `insert_drive_file_outlined`
/// for anything unknown — we never claim a preview the UI doesn't
/// actually render.
IconData _iconForAttachment(SupportAttachment a) {
  final mime = a.contentType.toLowerCase();
  if (mime.startsWith('image/')) return Icons.image_outlined;
  if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
  if (mime.contains('zip') || mime.contains('compressed')) {
    return Icons.folder_zip_outlined;
  }
  if (mime.contains('sheet') || mime.contains('excel') ||
      mime.contains('csv')) {
    return Icons.table_chart_outlined;
  }
  if (mime.contains('word') || mime.contains('document')) {
    return Icons.description_outlined;
  }
  // Fall back on the filename extension for content_type='' edge cases.
  final lower = a.originalFilename.toLowerCase();
  if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
  if (lower.endsWith('.zip')) return Icons.folder_zip_outlined;
  if (lower.endsWith('.png') || lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') || lower.endsWith('.gif')) {
    return Icons.image_outlined;
  }
  if (lower.endsWith('.csv') || lower.endsWith('.xls') ||
      lower.endsWith('.xlsx')) {
    return Icons.table_chart_outlined;
  }
  if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
    return Icons.description_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

/// Sanitize the original_filename for the on-disk path. We replace
/// path separators + control characters but preserve the extension
/// so the OS viewer routes based on it.
String _safeFilename(SupportAttachment a) {
  final raw = a.originalFilename.trim();
  final fallback = 'attachment_${a.id}';
  if (raw.isEmpty) return fallback;
  final cleaned = raw.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
  if (cleaned.isEmpty) return fallback;
  // Cap at a reasonable length so Windows / iOS filesystems are happy.
  return cleaned.length > 80 ? cleaned.substring(cleaned.length - 80) : cleaned;
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
