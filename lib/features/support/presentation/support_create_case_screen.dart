import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../data/support_repository.dart';

/// طلب دعم جديد (v88).
///
/// Posts to `POST /api/v1/support/cases`. The backend rejects empty
/// subject / body and tracks per-tenant quotas — both surface as
/// `ApiException`s that we render in-screen.
///
/// `kind` defaults to `message` (internal mail thread). Toggling to
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
      final detail = await ref.read(supportRepositoryProvider).createCase(
            kind: _kind,
            priority: _priority,
            subject: _subject.text.trim(),
            body: _body.text.trim(),
          );
      ref.invalidate(supportCasesProvider);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('تم إنشاء طلب الدعم.'),
        ));
      context.pushReplacement(
        AppRoutes.supportCase(detail.summary.type, detail.summary.id),
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
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(title: const Text('طلب دعم جديد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: AppCard(
              elevated: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'افتح طلب دعم جديد',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _KindPicker(
                    value: _kind,
                    onChanged: (v) => setState(() => _kind = v),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  _PriorityPicker(
                    value: _priority,
                    onChanged: (v) => setState(() => _priority = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: AppTheme.formControlHeight + 4,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, size: 18),
                      label: const Text('إرسال الطلب'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
            color: AppTheme.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
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
    final bg = selected ? AppTheme.indigoPrimary : AppTheme.surface;
    final fg = selected ? Colors.white : AppTheme.indigoPrimary;
    final border = selected
        ? AppTheme.indigoPrimary
        : AppTheme.indigoBright.withValues(alpha: 0.30);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
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
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 18, color: AppTheme.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.danger,
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
