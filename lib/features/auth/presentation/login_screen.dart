import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_config.dart';
import '../../../app/app_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/state/app_session.dart';

/// v100 — Login screen rebuilt on the design system.
///
/// Structure:
///   * Dark navy hero panel: logo + brand wordmark + tagline.
///   * Glossy white form card: username + password + error banner +
///     submit button + "create account" footer link.
///   * Backend URL whisper at the very bottom for support.
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
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _hydrateRestoreErrorIfNeeded();
    return ZynPage(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _BrandHero(),
              const SizedBox(height: 18),
              _FormCard(
                formKey: _formKey,
                username: _username,
                password: _password,
                obscure: _obscure,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                submitting: _submitting,
                error: _error,
                onSubmit: _submit,
                onGotoRegister: () => context.go(AppRoutes.register),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'الواجهة الخلفية: ${AppConfig.apiBaseUrl}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: ZynColors.faintMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Brand hero panel ──────────────────────────────────────────────

class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: zynHeroOuterDecoration(radius: 26),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: ZynColors.heroGradient),
          child: Stack(
            children: [
              // Cyan bloom in the top-right corner.
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF38BDF8).withValues(alpha: 0.40),
                        const Color(0xFF38BDF8).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Top specular sheen.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                child: Column(
                  children: [
                    // Logo
                    Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF38BDF8),
                            ZynColors.indigoBright,
                            ZynColors.indigoDeep,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ZynColors.indigoBright
                                .withValues(alpha: 0.50),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/branding/zynavolt_logo.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.wb_sunny_outlined,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'ZYNAVOLT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'منصة إدارة الطاقة الشمسية',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Form card ─────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.formKey,
    required this.username,
    required this.password,
    required this.obscure,
    required this.onToggleObscure,
    required this.submitting,
    required this.error,
    required this.onSubmit,
    required this.onGotoRegister,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController username;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final bool submitting;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onGotoRegister;

  @override
  Widget build(BuildContext context) {
    return ZynCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تسجيل الدخول',
              textAlign: TextAlign.center,
              style: ZynText.title,
            ),
            const SizedBox(height: 4),
            Text(
              'استخدم بيانات حسابك لمتابعة منظومات الطاقة الخاصة بك.',
              textAlign: TextAlign.center,
              style: ZynText.caption.copyWith(height: 1.6),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: username,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم أو البريد الإلكتروني',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: password,
              textInputAction: TextInputAction.done,
              obscureText: obscure,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'هذا الحقل مطلوب.' : null,
              onFieldSubmitted: (_) => onSubmit(),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: error!),
            ],
            const SizedBox(height: 22),
            ZynButton(
              label: 'دخول',
              icon: Icons.login_rounded,
              onTap: submitting ? null : onSubmit,
              busy: submitting,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ليس لديك حساب؟ ',
                  style: ZynText.caption.copyWith(fontSize: 12),
                ),
                TextButton(
                  onPressed: onGotoRegister,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'إنشاء حساب جديد',
                    style: TextStyle(
                      color: ZynColors.indigo,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error banner ──────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZynColors.danger.withValues(alpha: 0.14),
            ZynColors.danger.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(ZynRadii.tile),
        border: Border.all(
          color: ZynColors.danger.withValues(alpha: 0.32),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: ZynColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ZynColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
