import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/design/zyn_tokens.dart';
import '../../../core/api/multipart_file_spec.dart';
import '../data/support_models.dart';

/// v72: shared attachment-picker strip used by both the create-case
/// screen and the reply composer. Renders the user's draft picks as
/// small removable chips, plus a trailing "+" chip that opens the OS
/// file picker.
///
/// Phase-1 scope (per v72 brief):
///   * multi-file picker (documents + images),
///   * remove a picked file before submit,
///   * no camera capture, no compression, no preview.
class AttachmentDraftStrip extends StatelessWidget {
  const AttachmentDraftStrip({
    super.key,
    required this.drafts,
    required this.enabled,
    required this.onChanged,
  });

  /// Current draft list — owned by the parent screen so submit can
  /// pass the same `MultipartFileSpec` list to the repository.
  final List<AttachmentDraft> drafts;

  /// Disabled during submission so a second tap on "+" doesn't open
  /// the picker mid-upload.
  final bool enabled;

  /// Replacement callback (immutable list pattern). The strip emits a
  /// brand-new list so `setState` triggers a rebuild cleanly.
  final ValueChanged<List<AttachmentDraft>> onChanged;

  Future<void> _pickFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      // We rely on the backend's whitelist for the canonical
      // extension gate — pre-filtering here would duplicate that
      // list and drift; the v71 backend honestly reports each
      // rejection through `rejected_attachments[]` so the user sees
      // a clear summary after submit.
      withData: false,
    );
    if (result == null) return;
    final next = List<AttachmentDraft>.from(drafts);
    for (final picked in result.files) {
      if (picked.path == null || picked.path!.isEmpty) continue;
      // De-dupe by (name, size) so an accidental double-pick doesn't
      // double the upload.
      final exists = next.any(
        (d) => d.filename == picked.name && d.size == picked.size,
      );
      if (exists) continue;
      next.add(AttachmentDraft(
        filename: picked.name,
        path: picked.path!,
        size: picked.size,
      ));
    }
    onChanged(next);
  }

  void _remove(AttachmentDraft draft) {
    final next = drafts.where((d) => d != draft).toList();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.attach_file_outlined,
                size: 16, color: ZynColors.muted),
            const SizedBox(width: 6),
            const Text(
              'مرفقات (اختياري)',
              style: TextStyle(
                color: ZynColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: enabled ? () => _pickFiles(context) : null,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إضافة ملفات'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        if (drafts.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'يدعم النظام PDF وصور وWord وExcel وCSV وZIP حتى 10 ميغابايت لكل ملف.',
              style: TextStyle(
                color: ZynColors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.55,
              ),
            ),
          )
        else ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final draft in drafts)
                _DraftChip(
                  draft: draft,
                  enabled: enabled,
                  onRemove: () => _remove(draft),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// v72: one drafted attachment picked by the user, not yet uploaded.
/// Carries enough metadata to build a `MultipartFileSpec` at submit
/// time without re-opening the OS picker.
class AttachmentDraft {
  AttachmentDraft({
    required this.filename,
    required this.path,
    required this.size,
  });

  final String filename;
  final String path;
  final int size;

  MultipartFileSpec toSpec() => MultipartFileSpec(
        filename: filename,
        path: path,
      );

  /// "12.5 KB" / "3.4 MB". Matches the v69 `SupportAttachment.humanSize`
  /// formatting so picked + uploaded files read consistently in the
  /// thread.
  String get humanSize {
    if (size <= 0) return '';
    if (size < 1024) return '$size B';
    final kb = size / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024.0;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class _DraftChip extends StatelessWidget {
  const _DraftChip({
    required this.draft,
    required this.enabled,
    required this.onRemove,
  });

  final AttachmentDraft draft;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final sizeLabel = draft.humanSize;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ZynColors.primary50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ZynColors.primary500.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined,
              size: 14, color: ZynColors.primary700),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              draft.filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ZynColors.primary700,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (sizeLabel.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              sizeLabel,
              style: const TextStyle(
                color: ZynColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(width: 4),
          InkResponse(
            radius: 14,
            onTap: enabled ? onRemove : null,
            child: const Icon(Icons.close,
                size: 14, color: ZynColors.muted),
          ),
        ],
      ),
    );
  }
}

/// v72: format a `rejected_attachments[]` list as a single calm
/// Arabic snackbar caption. Returns `null` when the list is empty
/// so the caller can decide whether to show a generic success
/// snackbar instead.
String? buildRejectionSummary(
  List<RejectedAttachment> rejected, {
  required int savedCount,
}) {
  if (rejected.isEmpty) return null;
  final rejectedNames = rejected
      .map((r) => _formatRejection(r.filename, r.reasonCode, r.reasonMessage))
      .where((s) => s.isNotEmpty)
      .toList();
  if (rejectedNames.isEmpty) return null;
  final total = savedCount + rejected.length;
  final headline = 'تم رفع $savedCount من $total ملفات.';
  return '$headline تعذّر رفع: ${rejectedNames.join(' • ')}';
}

String _formatRejection(String filename, String code, String fallback) {
  final name = filename.isNotEmpty ? filename : 'ملف';
  switch (code) {
    case 'unsupported_extension':
      return '$name (نوع غير مدعوم)';
    case 'file_too_large':
      return '$name (أكبر من 10 ميغابايت)';
    default:
      final reason = fallback.trim();
      return reason.isEmpty ? name : '$name ($reason)';
  }
}
