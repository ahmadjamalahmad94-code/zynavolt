import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/state/app_session.dart';

/// v54 — subscriber self-registration screen.
///
/// Minimal field set matching the v54 brief ("keep it simple and
/// functional"). The backend `POST /api/mobile/auth/register`
/// accepts many more fields (country, city, timezone, phone, device
/// preference, etc.) but those have safe server-side defaults and
/// are far better collected during the existing onboarding flow,
/// which already deep-links into the profile editor for location /
/// timezone and into the add-device flow for the energy system.
///
/// On success, the screen does NOT navigate manually — the router
/// redirect handles it. The session controller flips to
/// `AppSessionPhase.authenticated`, the AuthUser comes back with
/// `onboarding.completed=false`, and the router sends the user
/// straight into `/onboarding`. There is no second first-run path.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _username,
      _password,
      _confirmPassword,
      _fullName,
      _email,
    ]) {
      c.addListener(_clearErrorOnInput);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _username,
      _password,
      _confirmPassword,
      _fullName,
      _email,
    ]) {
      c.removeListener(_clearErrorOnInput);
      c.dispose();
    }
    super.dispose();
  }

  void _clearErrorOnInput() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(appSessionProvider.notifier).register(
            username: _username.text.trim(),
            password: _password.text,
            fullName: _fullName.text,
            email: _email.text,
          );
      // Router redirect picks up the new session phase and lands the
      // user in /onboarding because the backend stamps
      // onboarding_completed=false on every new registration.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // v100 — rewrap on the design system: ZynPage backdrop +
    // dark navy brand hero + glossy white form card + ZynButton.
    return ZynPage(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const _BrandHero(),
              const SizedBox(height: 18),
              ZynCard(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'إنشاء حساب جديد',
                        textAlign: TextAlign.center,
                        style: ZynText.title,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'يكفي اسم مستخدم وكلمة مرور للبدء. تستكمل بياناتك وجهازك في خطوات قصيرة بعد إنشاء الحساب.',
                        textAlign: TextAlign.center,
                        style: ZynText.caption.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 22),
                      _UsernameField(controller: _username),
                      const SizedBox(height: 12),
                      _FullNameField(controller: _fullName),
                      const SizedBox(height: 12),
                      _EmailField(controller: _email),
                      const SizedBox(height: 12),
                      _PasswordField(
                        controller: _password,
                        obscure: _obscurePassword,
                        onToggleObscure: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ConfirmPasswordField(
                        controller: _confirmPassword,
                        passwordController: _password,
                        obscure: _obscureConfirm,
                        onToggleObscure: () => setState(
                          () => _obscureConfirm = !_obscureConfirm,
                        ),
                        onFieldSubmitted: _submit,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: 22),
                      ZynButton(
                        label: 'إنشاء الحساب',
                        icon: Icons.person_add_alt_1_rounded,
                        onTap: _submitting ? null : _submit,
                        busy: _submitting,
                      ),
                      const SizedBox(height: 14),
                      _LoginPrompt(onTap: _goToLogin),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToLogin() {
    // Use `go` (not `push`) so the back stack stays clean — login is
    // the canonical unauthenticated entry, not a child of register.
    context.go(AppRoutes.login);
  }
}

// ─── Brand hero ────────────────────────────────────────────────────

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
                        ZynColors.violet.withValues(alpha: 0.40),
                        ZynColors.violet.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
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
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
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
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ZynColors.indigoBright
                                .withValues(alpha: 0.45),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/branding/zynavolt_logo.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.wb_sunny_outlined,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ZYNAVOLT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'انضم إلى منصة إدارة الطاقة',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11.5,
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

// ─── Form fields ─────────────────────────────────────────────────────

class _UsernameField extends StatelessWidget {
  const _UsernameField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.newUsername],
      decoration: const InputDecoration(
        labelText: 'اسم المستخدم',
        hintText: 'ثلاثة أحرف على الأقل',
        prefixIcon: Icon(Icons.person_outline),
      ),
      validator: (v) {
        final s = (v ?? '').trim();
        if (s.isEmpty) return 'اسم المستخدم مطلوب.';
        if (s.length < 3) return 'يجب أن يحتوي على 3 أحرف على الأقل.';
        return null;
      },
    );
  }
}

class _FullNameField extends StatelessWidget {
  const _FullNameField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.name],
      decoration: const InputDecoration(
        labelText: 'الاسم الكامل (اختياري)',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(
        labelText: 'البريد الإلكتروني (اختياري)',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: (v) {
        final s = (v ?? '').trim();
        if (s.isEmpty) return null;
        // Honest minimal check — backend does its own validation +
        // duplicate detection, so we only catch the obvious typo
        // (missing @) here. No regex theatre.
        if (!s.contains('@') || s.length < 3) {
          return 'البريد الإلكتروني غير صحيح.';
        }
        return null;
      },
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggleObscure,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: 'كلمة المرور',
        hintText: 'ستة أحرف على الأقل',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: onToggleObscure,
        ),
      ),
      validator: (v) {
        final s = v ?? '';
        if (s.isEmpty) return 'كلمة المرور مطلوبة.';
        if (s.length < 6) return 'يجب أن تحتوي على 6 أحرف على الأقل.';
        return null;
      },
    );
  }
}

class _ConfirmPasswordField extends StatelessWidget {
  const _ConfirmPasswordField({
    required this.controller,
    required this.passwordController,
    required this.obscure,
    required this.onToggleObscure,
    required this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final TextEditingController passwordController;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'تأكيد كلمة المرور',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: onToggleObscure,
        ),
      ),
      validator: (v) {
        final s = v ?? '';
        if (s.isEmpty) return 'يرجى تأكيد كلمة المرور.';
        if (s != passwordController.text) {
          return 'كلمتا المرور غير متطابقتين.';
        }
        return null;
      },
      onFieldSubmitted: (_) => onFieldSubmitted(),
    );
  }
}

// ─── Login prompt + error banner ─────────────────────────────────────

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'لديك حساب بالفعل؟ ',
          style: TextStyle(
            color: ZynColors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'تسجيل الدخول',
            style: TextStyle(
              color: ZynColors.primary700,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
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
          const Icon(Icons.error_outline, size: 18, color: ZynColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ZynColors.danger,
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
