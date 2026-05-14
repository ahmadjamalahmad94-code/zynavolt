import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../data/support_repository.dart';
import 'attachment_draft_strip.dart';

/// v102 DS v1 — طلب دعم جديد.
///
/// Posts to `POST /api/v1/support/cases`. The backend rejects empty
/// subject / body and tracks per-tenant quotas — both surface as
/// `ApiException`s. `kind` defaults to `message`; switching to
/// `ticket` makes the case visible on the admin ticket queue.
class SupportCreateCaseScreen extends ConsumerStatefulWidget {
  const SupportCreateCaseScreen({super.key});

  @override
  ConsumerState<SupportCreateCaseScreen> createState() =>
      _SupportCreateCaseScreenState();
}

class _SupportCreateCaseScreenState
    extends ConsumerState<SupportCreateCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String _kind = 'message';
  String _priority = 'normal';
  bool _submitting = false;
  String? _error;
  List<AttachmentDraft> _attachments = const [];

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(supportRepositoryProvider).createCase(
            kind: _kind,
            priority: _priority,
            subject: _subject.text.trim(),
            body: _body.text.trim(),
            attachments: _attachments.map((d) => d.toSpec()).toList(),
          );
      ref.invalidate(supportCasesProvider);
      if (!mounted) return;
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
          content: Text(summary ?? 'تم إنشاء طلب الدعم.'),
        ));
      context.pushReplacement(
        AppRoutes.supportCase(
          result.caseDetail.summary.type,
          result.caseDetail.summary.id,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر إنشاء الطلب: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZynPage(
      appBar: AppBar(
        title: const Text('طلب دعم جديد'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient:
                              ZynGradients.iconFill(ZynColors.primary500),
                          borderRadius: BorderRadius.circular(ZynRadii.inner),
                          boxShadow:
                              ZynShadows.iconGlow(ZynColors.primary500),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: ZynSpacing.md),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'افتح طلب دعم جديد',
                              style: TextStyle(
                                color: ZynColors.ink,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'اختر النوع، الأولوية، ثم اشرح موقفك بإيجاز.',
                              style: TextStyle(
                                color: ZynColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZynSpacing.md),
                  _KindPicker(
                    value: _kind,
                    onChanged: (v) => setState(() => _kind = v),
                  ),
                  const SizedBox(height: ZynSpacing.md),
                  TextFormField(
                    controller: _subject,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'العنوان',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'العنوان مطلوب.'
                        : null,
                  ),
                  const SizedBox(height: ZynSpacing.md),
                  TextFormField(
                    controller: _body,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'نص الرسالة',
                      hintText: 'اشرح موقفك بإيجاز…',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'الرسالة مطلوبة.'
                        : null,
                  ),
                  const SizedBox(height: ZynSpacing.md),
                  _PriorityPicker(
                    value: _priority,
                    onChanged: (v) => setState(() => _priority = v),
                  ),
                  const SizedBox(height: ZynSpacing.md),
                  AttachmentDraftStrip(
                    drafts: _attachments,
                    enabled: !_submitting,
                    onChanged: (next) =>
                        setState(() => _attachments = next),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: ZynSpacing.md),
                    _ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: ZynSpacing.lg),
                  ZynButton(
                    label: 'إرسال الطلب',
                    icon: Icons.send_rounded,
                    busy: _submitting,
                    onTap: _submitting ? null : _submit,
                  ),
                ],
              ),
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
        ZynSpacing.lg,
        ZynSpacing.lg,
        ZynSpacing.lg,
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

class _KindPicker extends StatelessWidget {
  const _KindPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PillToggle(
            label: 'رسالة',
            selected: value == 'message',
            icon: Icons.mail_outline,
            onTap: () => onChanged('message'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PillToggle(
            label: 'تذكرة',
            selected: value == 'ticket',
            icon: Icons.confirmation_number_outlined,
            onTap: () => onChanged('ticket'),
          ),
        ),
      ],
    );
  }
}

class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الأولوية',
          style: TextStyle(
            color: ZynColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _PillToggle(
                label: 'عادية',
                selected: value == 'normal',
                onTap: () => onChanged('normal'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PillToggle(
                label: 'عالية',
                selected: value == 'high',
                onTap: () => onChanged('high'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PillToggle(
                label: 'عاجلة',
                selected: value == 'urgent',
                onTap: () => onChanged('urgent'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PillToggle extends StatelessWidget {
  const _PillToggle({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : ZynColors.primary700;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZynRadii.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ZynColors.primary500, ZynColors.primary700],
                  )
                : null,
            color: selected ? null : ZynColors.surface,
            borderRadius: BorderRadius.circular(ZynRadii.pill),
            border: Border.all(
              color: selected
                  ? ZynColors.primary700
                  : ZynColors.primary500.withValues(alpha: 0.30),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: ZynColors.primary500.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ZynColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZynRadii.inner),
        border: Border.all(color: ZynColors.danger.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: ZynColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ZynColors.danger,
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
}
