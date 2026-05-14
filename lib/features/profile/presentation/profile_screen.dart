import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/location_catalog_models.dart';
import '../data/location_catalog_repository.dart';
import '../data/profile_models.dart';
import '../state/profile_controller.dart';

/// v102 DS v1 — الملف الشخصي.
///
/// Full rebuild on the new design system. Form state + catalog
/// hydration + validation logic carried over unchanged; only the
/// rendered widget tree was rewritten.
///
/// Editable: full_name · email · phone_number · city ·
///           preferred_language · country · timezone ·
///           phone_country_code (catalog-validated)
/// Read-only: username · role · status
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);

    return ZynPage(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
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

  String? _countryCode;
  String? _timezone;
  String? _phoneDial;

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
    _timezone = widget.initial.timezone.isEmpty ? null : widget.initial.timezone;
    _phoneDial = widget.initial.phoneCountryCode.isEmpty
        ? null
        : widget.initial.phoneCountryCode;
  }

  @override
  void didUpdateWidget(covariant _ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.initial, widget.initial)) {
      _fullName.text = widget.initial.fullName;
      _email.text = widget.initial.email;
      _phoneNumber.text = widget.initial.phoneNumber;
      _city.text = widget.initial.city;
      _language = widget.initial.preferredLanguage.isEmpty
          ? 'ar'
          : widget.initial.preferredLanguage;
      _timezone =
          widget.initial.timezone.isEmpty ? null : widget.initial.timezone;
      _phoneDial = widget.initial.phoneCountryCode.isEmpty
          ? null
          : widget.initial.phoneCountryCode;
      _countryCode = null;
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
          current: widget.initial.preferredLanguage)
      ..setTimezone(_timezone, current: widget.initial.timezone)
      ..setPhoneCountryCode(_phoneDial,
          current: widget.initial.phoneCountryCode);

    final initialCountryCode = _initialCountryCodeForCompare();
    patch.setCountryCode(_countryCode, current: initialCountryCode);

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

  String _initialCountryCodeForCompare() {
    final catalog = ref.read(locationCatalogProvider).valueOrNull;
    if (catalog == null) return _countryCode ?? '';
    final match = catalog.findCountryByName(widget.initial.country);
    return match?.code ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.initial;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _IdentityHero(profile: p),
          const SizedBox(height: ZynSpacing.lg),
          const ZynSectionHeader(
            label: 'البيانات الأساسية',
            icon: Icons.edit_note_rounded,
          ),
          const SizedBox(height: ZynSpacing.sm),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  helper: 'اختر رمز الدولة من القائمة الرسمية.',
                  child: _PhoneRow(
                    currentDial: _phoneDial,
                    fallbackDial: widget.initial.phoneCountryCode,
                    numberController: _phoneNumber,
                    onDialChanged: (d) => setState(() => _phoneDial = d),
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
              ],
            ),
          ),
          const SizedBox(height: ZynSpacing.lg),
          const ZynSectionHeader(
            label: 'الموقع والمنطقة الزمنية',
            icon: Icons.public_rounded,
          ),
          const SizedBox(height: ZynSpacing.sm),
          _LocationContactCard(
            initial: p,
            countryCode: _countryCode,
            timezone: _timezone,
            onCountryChanged: (c) => setState(() => _countryCode = c),
            onTimezoneChanged: (tz) => setState(() => _timezone = tz),
          ),
          const SizedBox(height: ZynSpacing.lg),
          const ZynSectionHeader(
            label: 'معلومات النظام',
            icon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: ZynSpacing.sm),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'هذه الحقول يديرها الخادم ولا يمكن تعديلها من التطبيق.',
                  style: TextStyle(
                    color: ZynColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: ZynSpacing.md),
                _ReadOnlyRow(label: 'اسم المستخدم', value: p.username),
                _ReadOnlyRow(label: 'الدور', value: _displayRole(p)),
                _ReadOnlyRow(
                  label: 'حالة الحساب',
                  value: p.isActive ? 'نشط' : 'موقوف',
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: ZynSpacing.md),
            _InlineError(message: _error!),
          ],
          const SizedBox(height: ZynSpacing.xl),
          ZynButton(
            label: 'حفظ التغييرات',
            icon: Icons.save_outlined,
            busy: _saving,
            onTap: _saving ? null : _save,
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

// ─── Identity hero ────────────────────────────────────────────────

class _IdentityHero extends StatelessWidget {
  const _IdentityHero({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(profile.fullName, profile.username);
    final name = profile.fullName.isNotEmpty
        ? profile.fullName
        : profile.username;
    return Container(
      decoration: BoxDecoration(
        gradient: ZynGradients.glossSurface(tint: ZynColors.primary500),
        borderRadius: BorderRadius.circular(ZynRadii.xl),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.med(),
      ),
      padding: const EdgeInsets.fromLTRB(
        ZynSpacing.lg,
        ZynSpacing.lg,
        ZynSpacing.lg,
        ZynSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ZynColors.primary500, ZynColors.primary700],
              ),
              borderRadius: BorderRadius.circular(ZynRadii.xl),
              boxShadow: ZynShadows.iconGlow(ZynColors.primary500),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: ZynColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    height: 1.25,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  profile.email.isNotEmpty ? profile.email : '—',
                  style: const TextStyle(
                    color: ZynColors.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
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

// ─── Section card ────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ZynSpacing.lg,
        ZynSpacing.md,
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

// ─── Location + timezone (catalog-validated) ─────────────────────

class _LocationContactCard extends ConsumerWidget {
  const _LocationContactCard({
    required this.initial,
    required this.countryCode,
    required this.timezone,
    required this.onCountryChanged,
    required this.onTimezoneChanged,
  });

  final Profile initial;
  final String? countryCode;
  final String? timezone;
  final ValueChanged<String?> onCountryChanged;
  final ValueChanged<String?> onTimezoneChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(locationCatalogProvider);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تستخدم هذه الحقول قوائم محدّدة من خادم Zynavolt.',
            style: TextStyle(
              color: ZynColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              height: 1.55,
            ),
          ),
          catalog.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: ZynSpacing.lg),
              child: AppLoading(message: 'جارٍ تحميل القوائم...'),
            ),
            error: (err, _) => _CatalogFallback(profile: initial, error: err),
            data: (data) {
              final resolvedCountryCode =
                  countryCode ?? data.findCountryByName(initial.country)?.code;
              return _LocationEditors(
                catalog: data,
                lang: initial.preferredLanguage,
                resolvedCountryCode: resolvedCountryCode,
                hasOriginalCountry: initial.country.isNotEmpty,
                timezone: timezone,
                onCountryChanged: onCountryChanged,
                onTimezoneChanged: onTimezoneChanged,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LocationEditors extends StatelessWidget {
  const _LocationEditors({
    required this.catalog,
    required this.lang,
    required this.resolvedCountryCode,
    required this.hasOriginalCountry,
    required this.timezone,
    required this.onCountryChanged,
    required this.onTimezoneChanged,
  });

  final LocationCatalog catalog;
  final String lang;
  final String? resolvedCountryCode;
  final bool hasOriginalCountry;
  final String? timezone;
  final ValueChanged<String?> onCountryChanged;
  final ValueChanged<String?> onTimezoneChanged;

  @override
  Widget build(BuildContext context) {
    final countries = catalog.countries;
    final timezones = catalog.flatTimezones();
    final tzInCatalog = timezone == null || catalog.hasTimezone(timezone);
    final countryHelper = resolvedCountryCode == null && hasOriginalCountry
        ? 'لم نعثر على دولتك الحالية في القائمة. اختر قيمة من القائمة لتثبيتها.'
        : 'اختيار الدولة قد يضبط رمز الهاتف والمنطقة الزمنية تلقائياً.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabeledField(
          label: 'الدولة',
          helper: countryHelper,
          child: DropdownButtonFormField<String>(
            key: ValueKey('country-${resolvedCountryCode ?? ''}'),
            initialValue: resolvedCountryCode,
            isExpanded: true,
            items: [
              for (final c in countries)
                DropdownMenuItem(
                  value: c.code,
                  child: Text(
                    '${c.label(lang)}  ·  ${c.code}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onCountryChanged,
            decoration: const InputDecoration(),
          ),
        ),
        _LabeledField(
          label: 'المنطقة الزمنية',
          helper: tzInCatalog
              ? null
              : 'القيمة الحالية ليست في القائمة الرسمية؛ ستُستبدل عند اختيار قيمة جديدة.',
          child: DropdownButtonFormField<String>(
            key: ValueKey('tz-${(tzInCatalog ? timezone : null) ?? ''}'),
            initialValue: tzInCatalog ? timezone : null,
            isExpanded: true,
            items: [
              for (final t in timezones)
                DropdownMenuItem(
                  value: t.tz,
                  child: Text(t.label(lang), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onTimezoneChanged,
            decoration: const InputDecoration(),
          ),
        ),
      ],
    );
  }
}

// ─── Phone row ───────────────────────────────────────────────────

class _PhoneRow extends ConsumerWidget {
  const _PhoneRow({
    required this.currentDial,
    required this.fallbackDial,
    required this.numberController,
    required this.onDialChanged,
  });

  final String? currentDial;
  final String fallbackDial;
  final TextEditingController numberController;
  final ValueChanged<String?> onDialChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(locationCatalogProvider);
    final displayDial = currentDial ?? fallbackDial;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 132,
            child: catalog.when(
              loading: () => _DialPlainBox(text: displayDial),
              error: (_, _) => _DialPlainBox(text: displayDial),
              data: (data) {
                final inCatalog = data.hasPhonePrefix(displayDial);
                return DropdownButtonFormField<String>(
                  key: ValueKey('dial-${(inCatalog ? displayDial : null) ?? ''}'),
                  initialValue: inCatalog ? displayDial : null,
                  isExpanded: true,
                  items: [
                    for (final p in data.phonePrefixes)
                      DropdownMenuItem(
                        value: p.dial,
                        child: Text(
                          p.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: onDialChanged,
                  decoration: const InputDecoration(),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: numberController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: '599043337',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialPlainBox extends StatelessWidget {
  const _DialPlainBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ZynColors.bg,
        borderRadius: BorderRadius.circular(ZynRadii.inner),
        border: Border.all(color: ZynColors.line),
      ),
      child: Text(
        text.isNotEmpty ? text : '—',
        style: const TextStyle(
          color: ZynColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _CatalogFallback extends StatelessWidget {
  const _CatalogFallback({required this.profile, required this.error});
  final Profile profile;
  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : 'تعذّر تحميل قوائم الدولة والمنطقة الزمنية.';
    return Padding(
      padding: const EdgeInsets.only(top: ZynSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: ZynColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(ZynRadii.inner),
              border: Border.all(
                color: ZynColors.warning.withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_outlined,
                  size: 16,
                  color: ZynColors.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$message تعرض الحقول للقراءة فقط حالياً.',
                    style: const TextStyle(
                      color: ZynColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZynSpacing.sm),
          _ReadOnlyRow(label: 'الدولة', value: profile.country),
          _ReadOnlyRow(label: 'المنطقة الزمنية', value: profile.timezone),
          _ReadOnlyRow(
              label: 'رمز الدولة للهاتف', value: profile.phoneCountryCode),
        ],
      ),
    );
  }
}

// ─── Atoms ────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.only(top: ZynSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ZynColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          child,
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(
              helper!,
              style: const TextStyle(
                color: ZynColors.faint,
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                height: 1.5,
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
                color: ZynColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                color: ZynColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ZynColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZynRadii.inner),
        border: Border.all(color: ZynColors.danger.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: ZynColors.danger),
          const SizedBox(width: 6),
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
