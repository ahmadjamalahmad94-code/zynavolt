import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../data/account_repository.dart';

/// تغيير كلمة المرور (v89).
///
/// Calls `POST /api/mobile/account/change-password`. The backend enforces:
/// current password must verify; new password ≥ 6 characters. Locally we
/// add a confirm-password mismatch check to save a round-trip.
///
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
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(title: const Text('تغيير كلمة المرور')),
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
                    'حدّث كلمة المرور بأمان',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'سيُطلب منك إدخال كلمة المرور الحالية للتأكيد.',
                    style: TextStyle(
                      color: AppTheme.faintMuted,
                      fontSize: 12.5,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 14),
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    _ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: AppTheme.formControlHeight + 4,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('تحديث كلمة المرور'),
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
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
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
