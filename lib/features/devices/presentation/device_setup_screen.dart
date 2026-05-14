import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/device_detail_models.dart';
import '../data/device_provider_models.dart';
import '../data/device_providers_repository.dart';
import '../data/devices_repository.dart';

/// v49 — provider credential / setup form for an existing device.
///
/// Reached from [DeviceDetailScreen] when the device's
/// `connection_status` is `setup_required`. The form is generated
/// dynamically from the provider's `fields[]` metadata exposed by
/// `/api/mobile/device-providers`; mobile does NOT carry any
/// per-provider hardcoded form definitions.
///
/// Submits through `POST /api/mobile/devices/<id>/setup` which
/// persists into the same `credentials_json` / `settings_json`
/// storage the web flow uses (see
/// `web/app/blueprints/mobile_api.py:_mobile_apply_provider_setup`
/// + `web/app/blueprints/devices_routes.py:_save_device_fields`).
class DeviceSetupScreen extends ConsumerStatefulWidget {
  const DeviceSetupScreen({super.key, required this.device});

  /// The detail snapshot of the device being set up. Used to:
  ///   * Display the device's current name as the screen header
  ///     subtitle ("جهاز: …").
  ///   * Resolve the provider spec via `deviceType` lookup against
  ///     the cached [deviceProvidersListProvider].
  final DeviceDetail device;

  @override
  ConsumerState<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends ConsumerState<DeviceSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _obscure = {};
  bool _submitting = false;
  String? _serverError;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Lazily create + cache controllers for each provider field. The
  /// map keys are field `name`s (e.g. `deye_app_id`); secret fields
  /// default to obscured input.
  TextEditingController _controllerFor(ProviderFieldSpec spec) {
    return _controllers.putIfAbsent(spec.name, () {
      _obscure[spec.name] = spec.secret;
      return TextEditingController();
    });
  }

  Future<void> _submit(ProviderOption option) async {
    if (_submitting) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    // Build the JSON payload. Blank values are sent as empty strings;
    // the backend treats blanks as "no change" so secret fields can be
    // safely re-saved without re-typing every credential.
    final fields = <String, String>{};
    for (final f in option.fields) {
      final c = _controllers[f.name];
      if (c == null) continue;
      final v = c.text.trim();
      if (v.isEmpty) continue;
      fields[f.name] = v;
    }
    if (fields.isEmpty) {
      setState(() => _serverError = 'لم يتم إدخال أي قيم للحفظ.');
      return;
    }

    setState(() {
      _submitting = true;
      _serverError = null;
    });
    try {
      await ref.read(devicesRepositoryProvider).submitProviderSetup(
            deviceId: widget.device.id,
            fields: fields,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverError = e.message;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serverError = 'تعذّر حفظ بيانات الإعداد: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(deviceProvidersListProvider);
    return ZynScreen(
      hero: const ZynPageHero(
        title: 'إكمال إعداد المزوّد',
        subtitle: 'بيانات الاعتماد المطلوبة لربط الجهاز بحساب المزوّد.',
      ),
      child: providers.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: AppLoading(message: 'جارٍ تحميل المزوّدين...'),
        ),
        error: (err, _) => AppErrorState(
          error: err is ApiException
              ? err
              : ApiException(
                  message: 'تعذّر تحميل المزوّدين.',
                  kind: ApiErrorKind.unknown,
                ),
          onRetry: () => ref.invalidate(deviceProvidersListProvider),
        ),
        data: (list) => _buildForm(context, list),
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<ProviderOption> providers) {
    final code = widget.device.deviceType.trim().toLowerCase();
    final option = providers.firstWhere(
      (p) => p.code.toLowerCase() == code,
      orElse: () => ProviderOption(
        code: code,
        displayName: widget.device.deviceType,
        supportTier: '',
        supportTierLabel: '',
        fields: const [],
        notesAr: '',
      ),
    );

    if (option.fields.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'لا توجد حقول إعداد متاحة لهذا المزوّد',
                style: TextStyle(
                  color: ZynColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'يبدو أن المزوّد «${option.displayName}» لا يعرّف حقول '
                'إعداد قابلة للتعبئة من التطبيق حالياً. تواصل مع الدعم '
                'إذا كنت بحاجة إلى تكوين خاص.',
                style: const TextStyle(
                  color: ZynColors.inkSoft,
                  fontSize: 12.5,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final required = option.fields.where((f) => f.required).toList();
    final optional = option.fields.where((f) => !f.required).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(option: option, deviceName: widget.device.name),
            const SizedBox(height: 12),
            const _HonestNote(),
            const SizedBox(height: 14),
            if (required.isNotEmpty) ...[
              const _SectionLabel(text: 'الحقول المطلوبة'),
              const SizedBox(height: 6),
              for (final f in required) ...[
                _FieldEditor(
                  spec: f,
                  controller: _controllerFor(f),
                  obscured: _obscure[f.name] ?? f.secret,
                  onToggleObscure: () => setState(
                    () => _obscure[f.name] = !(_obscure[f.name] ?? f.secret),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
            if (optional.isNotEmpty) ...[
              const SizedBox(height: 6),
              const _SectionLabel(text: 'الحقول الاختيارية'),
              const SizedBox(height: 6),
              for (final f in optional) ...[
                _FieldEditor(
                  spec: f,
                  controller: _controllerFor(f),
                  obscured: _obscure[f.name] ?? f.secret,
                  onToggleObscure: () => setState(
                    () => _obscure[f.name] = !(_obscure[f.name] ?? f.secret),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
            if (_serverError != null) ...[
              const SizedBox(height: 6),
              _ErrorBanner(message: _serverError!),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 46.0,
              child: FilledButton.icon(
                onPressed: _submitting ? null : () => _submit(option),
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 18),
                label: const Text('حفظ بيانات الإعداد'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.option, required this.deviceName});
  final ProviderOption option;
  final String deviceName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (option.supportTierLabel.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: ZynColors.primary50,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    option.supportTierLabel,
                    style: const TextStyle(
                      color: ZynColors.primary700,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option.displayName,
                  style: const TextStyle(
                    color: ZynColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (deviceName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'الجهاز: $deviceName',
              style: const TextStyle(
                color: ZynColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (option.notesAr.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              option.notesAr,
              style: const TextStyle(
                color: ZynColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HonestNote extends StatelessWidget {
  const _HonestNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ZynColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.warning.withValues(alpha: 0.30)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: ZynColors.warning, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'بعد الحفظ، تظل حالة الجهاز «بحاجة إلى إعداد» حتى تنجح '
              'أوّل عملية مزامنة فعلية مع المزوّد. عندها تتحوّل الحالة '
              'إلى «متصل» تلقائياً.',
              style: TextStyle(
                color: ZynColors.warning,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: ZynColors.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _FieldEditor extends StatelessWidget {
  const _FieldEditor({
    required this.spec,
    required this.controller,
    required this.obscured,
    required this.onToggleObscure,
  });

  final ProviderFieldSpec spec;
  final TextEditingController controller;
  final bool obscured;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    final isSecret = spec.secret;
    return TextFormField(
      controller: controller,
      obscureText: isSecret && obscured,
      autocorrect: !isSecret,
      enableSuggestions: !isSecret,
      decoration: InputDecoration(
        labelText: spec.label,
        hintText: spec.required ? 'مطلوب' : 'اختياري',
        prefixIcon: Icon(
          isSecret ? Icons.lock_outline : Icons.short_text,
          color: isSecret ? ZynColors.warning : ZynColors.primary700,
        ),
        suffixIcon: isSecret
            ? IconButton(
                icon: Icon(
                  obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                ),
                onPressed: onToggleObscure,
                tooltip: obscured ? 'إظهار' : 'إخفاء',
              )
            : null,
      ),
      validator: (v) {
        if (!spec.required) return null;
        final s = (v ?? '').trim();
        if (s.isEmpty) return 'هذا الحقل مطلوب.';
        return null;
      },
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
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.danger.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: ZynColors.danger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ZynColors.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
