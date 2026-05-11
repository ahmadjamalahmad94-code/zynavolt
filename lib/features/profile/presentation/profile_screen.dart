import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/profile_models.dart';
import '../state/profile_controller.dart';

/// Profile screen — read + safe edit.
///
/// Editable in v42:  full_name · email · phone_number · city ·
///                   preferred_language
/// Read-only in v42: username · role · status · country · timezone ·
///                   phone_country_code (catalog-bound — needs a future
///                   catalog endpoint before becoming editable)
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: profile.when(
          loading: () => const AppLoading(message: 'جارٍ تحميل الملف...'),
          error: (err, _) => AppErrorState(
            error: err is ApiException
                ? err
                : ApiException(
                    message: 'تعذّر تحميل الملف الشخصي.',
                    kind: ApiErrorKind.unknown,
                  ),
            onRetry: () =>
                ref.read(profileControllerProvider.notifier).refresh(),
          ),
          data: (data) => _ProfileForm(initial: data),
        ),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.initial});
  final Profile initial;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late final TextEditingController _phoneNumber;
  late final TextEditingController _city;
  late String _language;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: widget.initial.fullName);
    _email = TextEditingController(text: widget.initial.email);
    _phoneNumber = TextEditingController(text: widget.initial.phoneNumber);
    _city = TextEditingController(text: widget.initial.city);
    _language = widget.initial.preferredLanguage.isEmpty
        ? 'ar'
        : widget.initial.preferredLanguage;
  }

  @override
  void didUpdateWidget(covariant _ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The controller may emit a new Profile after a successful save —
    // reseat the controllers so the displayed text matches the saved values
    // (including server-side normalisation like email lower-casing).
    if (!identical(oldWidget.initial, widget.initial)) {
      _fullName.text = widget.initial.fullName;
      _email.text = widget.initial.email;
      _phoneNumber.text = widget.initial.phoneNumber;
      _city.text = widget.initial.city;
      _language = widget.initial.preferredLanguage.isEmpty
          ? 'ar'
          : widget.initial.preferredLanguage;
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phoneNumber.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final patch = ProfilePatch()
      ..setFullName(_fullName.text, current: widget.initial.fullName)
      ..setEmail(_email.text, current: widget.initial.email)
      ..setPhoneNumber(_phoneNumber.text, current: widget.initial.phoneNumber)
      ..setCity(_city.text, current: widget.initial.city)
      ..setPreferredLanguage(_language,
          current: widget.initial.preferredLanguage);

    if (patch.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد تغييرات للحفظ.')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileControllerProvider.notifier).save(patch);
      messenger.showSnackBar(
        const SnackBar(content: Text('تم حفظ الملف الشخصي بنجاح.')),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'تعذّر الحفظ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.initial;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _IdentityCard(profile: p),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(title: 'البيانات القابلة للتعديل'),
                const SizedBox(height: 10),
                _LabeledField(
                  label: 'الاسم الكامل',
                  child: TextFormField(
                    controller: _fullName,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'أدخل اسمك كما تحب أن يظهر',
                    ),
                    validator: (v) =>
                        (v != null && v.length > 120) ? 'الاسم طويل جداً.' : null,
                  ),
                ),
                _LabeledField(
                  label: 'البريد الإلكتروني',
                  helper: 'يستخدم لتسجيل الدخول والتنبيهات.',
                  child: TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'name@example.com',
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return null;
                      if (!value.contains('@')) {
                        return 'صيغة البريد غير صالحة.';
                      }
                      return null;
                    },
                  ),
                ),
                _LabeledField(
                  label: 'رقم الهاتف',
                  helper: 'الأرقام فقط، بدون رمز الدولة.',
                  child: TextFormField(
                    controller: _phoneNumber,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'مثل: 599043337',
                    ),
                  ),
                ),
                _LabeledField(
                  label: 'المدينة',
                  child: TextFormField(
                    controller: _city,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'مدينتك الحالية',
                    ),
                  ),
                ),
                _LabeledField(
                  label: 'لغة التطبيق المفضلة',
                  helper: 'يطبَّق الإعداد على رسائل النظام والتنبيهات.',
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ar', label: Text('العربية')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {_language},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _language = s.first),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  _InlineError(message: _error!),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  height: AppTheme.formControlHeight + 4,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('حفظ التغييرات'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(title: 'معلومات للقراءة فقط'),
                const SizedBox(height: 6),
                const Text(
                  'هذه الحقول مرتبطة بقوائم على الخادم وستصبح قابلة للتعديل في مرحلة لاحقة.',
                  style: TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 10),
                _ReadOnlyRow(label: 'اسم المستخدم', value: p.username),
                _ReadOnlyRow(label: 'الدور', value: _displayRole(p)),
                _ReadOnlyRow(
                  label: 'حالة الحساب',
                  value: p.isActive ? 'نشط' : 'موقوف',
                ),
                _ReadOnlyRow(label: 'الدولة', value: p.country),
                _ReadOnlyRow(label: 'المنطقة الزمنية', value: p.timezone),
                _ReadOnlyRow(
                    label: 'رمز الدولة للهاتف', value: p.phoneCountryCode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _displayRole(Profile p) {
    if (p.roleLabel.isNotEmpty) return p.roleLabel;
    if (p.role.isNotEmpty) return p.role;
    return '—';
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(profile.fullName, profile.username);
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.indigoSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: AppTheme.indigoPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName.isNotEmpty
                      ? profile.fullName
                      : profile.username,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.email.isNotEmpty ? profile.email : '—',
                  style: const TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name, String username) {
    final source = (name.isNotEmpty ? name : username).trim();
    if (source.isEmpty) return '؟';
    final parts =
        source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return source.characters.first;
    if (parts.length == 1) return parts.first.characters.first;
    return parts.first.characters.first + parts.last.characters.first;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.ink,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.helper,
  });

  final String label;
  final String? helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          child,
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(
              helper!,
              style: const TextStyle(
                color: AppTheme.faintMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppTheme.danger),
          const SizedBox(width: 6),
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
