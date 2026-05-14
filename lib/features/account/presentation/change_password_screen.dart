import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../data/account_repository.dart';

/// v102 DS v1 — تغيير كلمة المرور.
///
/// Calls `POST /api/mobile/account/change-password`. The backend
/// enforces: current password must verify; new password ≥ 6 chars.
/// Locally we add a confirm-mismatch check to save a round-trip.
/// Passwords are never persisted, logged, or echoed.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _hideCurrent = true;
  bool _hideNext = true;
  bool _hideConfirm = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_next.text != _confirm.text) {
      setState(() => _error = 'كلمتا المرور الجديدتان غير متطابقتين.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountRepositoryProvider).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('تم تغيير كلمة المرور.'),
        ));
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر تغيير كلمة المرور: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZynPage(
      appBar: AppBar(
        title: const Text('تغيير كلمة المرور'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const SizedBox(height: ZynSpacing.md),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PasswordField(
                    controller: _current,
                    label: 'كلمة المرور الحالية',
                    obscure: _hideCurrent,
                    onToggle: () =>
                        setState(() => _hideCurrent = !_hideCurrent),
                    autoFocus: true,
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'هذا الحقل مطلوب.'
                        : null,
                  ),
                  const SizedBox(height: ZynSpacing.md),
                  _PasswordField(
                    controller: _next,
                    label: 'كلمة المرور الجديدة',
                    obscure: _hideNext,
                    onToggle: () => setState(() => _hideNext = !_hideNext),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'هذا الحقل مطلوب.';
                      if (v.length < 6) return 'يجب ألا تقل عن 6 أحرف.';
                      return null;
                    },
                  ),
                  const SizedBox(height: ZynSpacing.md),
                  _PasswordField(
                    controller: _confirm,
                    label: 'تأكيد كلمة المرور',
                    obscure: _hideConfirm,
                    onToggle: () =>
                        setState(() => _hideConfirm = !_hideConfirm),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'هذا الحقل مطلوب.';
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: ZynSpacing.md),
                    _ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: ZynSpacing.lg),
                  ZynButton(
                    label: 'تحديث كلمة المرور',
                    icon: Icons.lock_outline_rounded,
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

class _Header extends StatelessWidget {
  const _Header();

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
        gradient: ZynGradients.glossSurface(tint: ZynColors.primary500),
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.soft(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: ZynGradients.iconFill(ZynColors.primary500),
              borderRadius: BorderRadius.circular(ZynRadii.inner),
              boxShadow: ZynShadows.iconGlow(ZynColors.primary500),
            ),
            child: const Icon(
              Icons.shield_outlined,
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
                  'حدّث كلمة المرور بأمان',
                  style: TextStyle(
                    color: ZynColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'سيُطلب منك إدخال كلمة المرور الحالية للتأكيد.',
                  style: TextStyle(
                    color: ZynColors.inkSoft,
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

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.validator,
    this.autoFocus = false,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?) validator;
  final bool autoFocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autoFocus,
      obscureText: obscure,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: ZynColors.muted),
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: ZynColors.muted,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
