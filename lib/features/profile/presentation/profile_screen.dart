import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/location_catalog_models.dart';
import '../data/location_catalog_repository.dart';
import '../data/profile_models.dart';
import '../state/profile_controller.dart';

/// Profile screen — read + safe edit.
///
/// Editable in v44:  full_name · email · phone_number · city ·
///                   preferred_language · country · timezone ·
///                   phone_country_code (catalog-validated)
/// Read-only:        username · role · status — server-managed
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);

    // v100 — gradient backdrop for visual continuity with Home/More.
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.pageBackdropGradient),
        child: SafeArea(
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
      ),  // close DecoratedBox
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

  // Catalog-bound selections. `null` means "user has not picked a value
  // yet — fall back to whatever the catalog resolves from the Profile".
  // Once the user touches a dropdown, this becomes the source of truth.
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
    _timezone = widget.initial.timezone.isEmpty
        ? null
        : widget.initial.timezone;
    _phoneDial = widget.initial.phoneCountryCode.isEmpty
        ? null
        : widget.initial.phoneCountryCode;
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
      _timezone = widget.initial.timezone.isEmpty
          ? null
          : widget.initial.timezone;
      _phoneDial = widget.initial.phoneCountryCode.isEmpty
          ? null
          : widget.initial.phoneCountryCode;
      // Reset the user's country selection so the next render picks up the
      // newly-saved profile value via the inline catalog lookup.
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

    // The country PATCH uses `country_code` so the backend can resolve the
    // localised name. The current code is whatever the catalog matched on
    // initial hydration; if nothing matched, _initialCountryCode is null
    // and any selection counts as a change.
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

  /// Derive the country_code that would have been sent if the user had not
  /// touched the dropdown — used by [ProfilePatch.setCountryCode] to decide
  /// "did this change". On first build, _countryCode is the catalog match
  /// of the initial country name; after the user picks a new option, this
  /// helper still returns that original baseline.
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
                  helper: 'اختر رمز الدولة من القائمة الرسمية.',
                  child: _PhoneRow(
                    currentDial: _phoneDial,
                    fallbackDial: widget.initial.phoneCountryCode,
                    numberController: _phoneNumber,
                    onDialChanged: (dial) => setState(() => _phoneDial = dial),
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
          _LocationContactCard(
            initial: p,
            countryCode: _countryCode,
            timezone: _timezone,
            onCountryChanged: (code) => setState(() => _countryCode = code),
            onTimezoneChanged: (tz) => setState(() => _timezone = tz),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(title: 'معلومات للقراءة فقط'),
                const SizedBox(height: 6),
                const Text(
                  'هذه الحقول يديرها الخادم ولا يمكن تعديلها من التطبيق.',
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

/// Card holding the catalog-validated location selectors (country +
/// timezone). Phone prefix lives in the contact row inside the editable
/// section so it sits next to the phone number.
///
/// Loads the catalog through `locationCatalogProvider`. While loading or
/// on error the dropdowns degrade to read-only rows — the user is never
/// offered fake options.
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'الموقع والمنطقة الزمنية'),
          const SizedBox(height: 6),
          const Text(
            'تستخدم هذه الحقول قوائم محدّدة من خادم Zynavolt.',
            style: TextStyle(
              color: AppTheme.faintMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          catalog.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: AppLoading(message: 'جارٍ تحميل القوائم...'),
            ),
            error: (err, _) => _CatalogFallback(profile: initial, error: err),
            data: (data) {
              // Resolve the displayed country code inline. Priority:
              //   1. user's in-progress selection (`countryCode`)
              //   2. catalog match against the saved country name
              //   3. null (dropdown shows no selection + helper hint)
              // No post-frame callback / setState-after-build needed.
              final resolvedCountryCode = countryCode ??
                  data.findCountryByName(initial.country)?.code;
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
            // The dropdown only mounts inside the `catalog.when(data:)` branch,
            // so `resolvedCountryCode` is already the right value at first
            // mount — no value-vs-initialValue race.
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

/// Compact phone row: a narrow prefix dropdown sourced from the catalog,
/// plus the existing phone-number text field, on one LTR line so the
/// composed value reads naturally as "+970 599043337" — matches the
/// canonical web v35 phone display.
class _PhoneRow extends ConsumerWidget {
  const _PhoneRow({
    required this.currentDial,
    required this.fallbackDial,
    required this.numberController,
    required this.onDialChanged,
  });

  /// In-progress user selection. `null` means the user has not touched
  /// the dropdown yet; we fall back to [fallbackDial] from the profile.
  final String? currentDial;

  /// The phone_country_code value from the saved profile.
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

/// Calm read-only stand-in for the dial dropdown while the catalog is
/// loading or has failed. Matches the dropdown's height + radius so the
/// row never jumps when the catalog finishes loading.
class _DialPlainBox extends StatelessWidget {
  const _DialPlainBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppTheme.formControlHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.softBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(
        text.isNotEmpty ? text : '—',
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 13,
          fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_outlined,
                    size: 16, color: AppTheme.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$message تعرض الحقول للقراءة فقط حالياً.',
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _ReadOnlyRow(label: 'الدولة', value: profile.country),
          _ReadOnlyRow(label: 'المنطقة الزمنية', value: profile.timezone),
          _ReadOnlyRow(
              label: 'رمز الدولة للهاتف', value: profile.phoneCountryCode),
        ],
      ),
    );
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
