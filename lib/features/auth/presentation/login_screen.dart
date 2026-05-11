import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_config.dart';
import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/state/app_session.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  String? _error;
  bool _restoreErrorChecked = false;

  @override
  void initState() {
    super.initState();
    _username.addListener(_clearErrorOnInput);
    _password.addListener(_clearErrorOnInput);
  }

  @override
  void dispose() {
    _username.removeListener(_clearErrorOnInput);
    _password.removeListener(_clearErrorOnInput);
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearErrorOnInput() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  /// Pull `AppSession.lastError` exactly once on first build so a failed
  /// cold-start restore (network down, refresh token expired, etc.) is
  /// honestly visible instead of silently dumping the user back here.
  void _hydrateRestoreErrorIfNeeded() {
    if (_restoreErrorChecked) return;
    _restoreErrorChecked = true;
    final lastError = ref.read(appSessionProvider).lastError;
    if (lastError != null && _error == null) {
      _error = lastError.message;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(appSessionProvider.notifier).signIn(
            username: _username.text.trim(),
            password: _password.text,
          );
      // Router redirect picks up the new session phase.
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _hydrateRestoreErrorIfNeeded();
    return Scaffold(
      backgroundColor: Colors.transparent,
      // v46: match the Home pale-indigo backdrop so Splash → Login → Home
      // feel like one continuous brand surface.
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE0E7FF),
              Color(0xFFF1F5FF),
              Color(0xFFF8FAFC),
            ],
            stops: [0.0, 0.35, 0.85],
          ),
        ),
        child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // v46: Zynavolt logo with calm fallback to the prior
                  // sun-icon tile so the screen never breaks if the PNG
                  // asset is missing during dev / pre-release builds.
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/branding/zynavolt_logo.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.indigoSoft,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.wb_sunny_outlined,
                            color: AppTheme.indigoPrimary,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'تسجيل الدخول إلى Zynavolt',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'استخدم بيانات حسابك لمتابعة منظومات الطاقة الشمسية الخاصة بك.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.faintMuted,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _username,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'اسم المستخدم أو البريد الإلكتروني',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'هذا الحقل مطلوب.'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          textInputAction: TextInputAction.done,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'هذا الحقل مطلوب.'
                              : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          _ErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          height: AppTheme.formControlHeight + 4,
                          child: FilledButton(
                            onPressed: _submitting ? null : _submit,
                            child: _submitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('دخول'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            'الواجهة الخلفية: ${AppConfig.apiBaseUrl}',
                            style: const TextStyle(
                              color: AppTheme.faintMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
          const Icon(Icons.error_outline, size: 18, color: AppTheme.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.danger,
                fontSize: 12,
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
