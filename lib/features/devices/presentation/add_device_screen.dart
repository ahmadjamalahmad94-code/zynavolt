import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/zyn_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/device_provider_models.dart';
import '../data/device_providers_repository.dart';
import '../data/devices_repository.dart';

/// v48 — minimal first slice of the mobile add-device flow.
///
/// Backend reality check (verified against
/// `_mobile_apply_device_fields` in `web/app/blueprints/mobile_api.py`):
/// the `POST /api/mobile/devices` endpoint accepts only:
///   * `name` (required)
///   * `device_type` (required — provider code)
///   * `plant_name` (optional)
///   * `timezone` (optional)
///   * `safe_settings` (optional — `battery_capacity_kwh` /
///     `battery_reserve_percent`)
///
/// Provider credential fields (e.g. `deye_app_id`) are NOT processed
/// by this endpoint — they are saved through the web `/devices/manage`
/// form into `credentials_json`. New devices are stamped server-side
/// with `connection_status='setup_required'`.
///
/// This screen therefore:
///   * Renders a provider picker driven entirely by
///     `/api/mobile/device-providers` (with v45 Arabic tier badges).
///   * Renders only the identity fields the backend accepts.
///   * Renders the selected provider's REQUIRED credential fields as
///     a small **informational** chip strip ("سوف تحتاج هذه البيانات
///     لاحقاً") so the user knows what completing setup on the web
///     will need.
///   * Submits the create POST and pops back with a success result
///     so the caller can invalidate `devicesListProvider`.
class AddDeviceScreen extends ConsumerStatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  ConsumerState<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends ConsumerState<AddDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _plantCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _reserveCtrl = TextEditingController();

  ProviderOption? _selected;
  bool _submitting = false;
  String? _serverError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _plantCtrl.dispose();
    _capacityCtrl.dispose();
    _reserveCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final selected = _selected;
    if (selected == null) {
      setState(() => _serverError = 'يرجى اختيار المزوّد قبل الحفظ.');
      return;
    }

    setState(() {
      _submitting = true;
      _serverError = null;
    });

    try {
      await ref.read(devicesRepositoryProvider).create(
            name: _nameCtrl.text.trim(),
            deviceType: selected.code,
            plantName: _plantCtrl.text.trim(),
            batteryCapacityKwh: _parseDouble(_capacityCtrl.text),
            batteryReservePercent: _parseDouble(_reserveCtrl.text),
          );
      if (!mounted) return;
      // The caller (devices_screen) invalidates the list provider via
      // the popped `true` result so the new device row appears
      // immediately. No client-side optimistic insert.
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
        _serverError = 'تعذّر إنشاء الجهاز: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(deviceProvidersListProvider);
    return Scaffold(
      backgroundColor: ZynColors.bg,
      appBar: AppBar(title: const Text('إضافة جهاز')),
      body: SafeArea(
        child: providers.when(
          loading: () => const AppLoading(message: 'جارٍ تحميل المزوّدين...'),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: AppErrorState(
              error: err is ApiException
                  ? err
                  : ApiException(
                      message: 'تعذّر تحميل المزوّدين.',
                      kind: ApiErrorKind.unknown,
                    ),
              onRetry: () => ref.invalidate(deviceProvidersListProvider),
            ),
          ),
          data: _buildForm,
        ),
      ),
    );
  }

  Widget _buildForm(List<ProviderOption> providers) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _IntroNote(),
            const SizedBox(height: 12),
            _ProviderPicker(
              providers: providers,
              selected: _selected,
              onChanged: (p) => setState(() => _selected = p),
            ),
            if (_selected != null) ...[
              const SizedBox(height: 12),
              _SelectedProviderNote(option: _selected!),
            ],
            const SizedBox(height: 16),
            _NameField(controller: _nameCtrl),
            const SizedBox(height: 12),
            _PlantNameField(controller: _plantCtrl),
            const SizedBox(height: 12),
            _BatteryCapacityField(controller: _capacityCtrl),
            const SizedBox(height: 12),
            _BatteryReserveField(controller: _reserveCtrl),
            if (_serverError != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: _serverError!),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 46.0,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
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
                label: const Text('حفظ الجهاز'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Intro note ──────────────────────────────────────────────────────

class _IntroNote extends StatelessWidget {
  const _IntroNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ZynColors.primary50,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.primary500.withValues(alpha: 0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              color: ZynColors.primary700, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'سيُنشأ الجهاز بحالة «بحاجة إلى إعداد». تُكمل بيانات الاتصال '
              'بالمزوّد لاحقاً من الموقع.',
              style: TextStyle(
                color: ZynColors.primary700,
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

// ─── Provider picker ─────────────────────────────────────────────────

class _ProviderPicker extends StatelessWidget {
  const _ProviderPicker({
    required this.providers,
    required this.selected,
    required this.onChanged,
  });

  final List<ProviderOption> providers;
  final ProviderOption? selected;
  final ValueChanged<ProviderOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'المزوّد',
            style: TextStyle(
              color: ZynColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'اختر مزوّد بيانات الجهاز.',
            style: TextStyle(
              color: ZynColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selected?.code,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.solar_power_outlined),
              hintText: '— اختر —',
            ),
            isExpanded: true,
            items: [
              for (final p in providers)
                DropdownMenuItem<String>(
                  value: p.code,
                  child: _DropdownLine(option: p),
                ),
            ],
            onChanged: (code) {
              if (code == null) return;
              final picked = providers.firstWhere(
                (p) => p.code == code,
                orElse: () => providers.first,
              );
              onChanged(picked);
            },
            validator: (v) =>
                (v == null || v.isEmpty) ? 'يرجى اختيار المزوّد.' : null,
          ),
        ],
      ),
    );
  }
}

class _DropdownLine extends StatelessWidget {
  const _DropdownLine({required this.option});
  final ProviderOption option;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            option.displayName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ZynColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (option.supportTierLabel.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            '· ${option.supportTierLabel}',
            style: const TextStyle(
              color: ZynColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Post-selection informational block ──────────────────────────────

class _SelectedProviderNote extends StatelessWidget {
  const _SelectedProviderNote({required this.option});
  final ProviderOption option;

  @override
  Widget build(BuildContext context) {
    final required = option.requiredFields;
    return AppCard(
      background: ZynColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (option.supportTierLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (option.notesAr.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              option.notesAr,
              style: const TextStyle(
                color: ZynColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
            ),
          ],
          if (required.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'سوف تحتاج هذه البيانات لاحقاً عند إكمال الإعداد على الموقع:',
              style: TextStyle(
                color: ZynColors.inkSoft,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in required)
                  _FieldChip(label: f.label, secret: f.secret),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldChip extends StatelessWidget {
  const _FieldChip({required this.label, required this.secret});
  final String label;
  final bool secret;

  @override
  Widget build(BuildContext context) {
    final tone = secret ? ZynColors.warning : ZynColors.primary700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            secret ? Icons.lock_outline : Icons.short_text,
            size: 11,
            color: tone,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Form fields ─────────────────────────────────────────────────────

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'اسم الجهاز',
        hintText: 'مثلاً: سطح المنزل',
        prefixIcon: Icon(Icons.edit_outlined),
      ),
      textInputAction: TextInputAction.next,
      maxLength: 120,
      validator: (v) {
        final s = (v ?? '').trim();
        if (s.isEmpty) return 'الاسم مطلوب.';
        return null;
      },
    );
  }
}

class _PlantNameField extends StatelessWidget {
  const _PlantNameField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'اسم المحطة / الموقع (اختياري)',
        prefixIcon: Icon(Icons.location_on_outlined),
      ),
      textInputAction: TextInputAction.next,
      maxLength: 120,
    );
  }
}

class _BatteryCapacityField extends StatelessWidget {
  const _BatteryCapacityField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'سعة البطارية بالكيلوواط·ساعة (اختياري)',
        hintText: 'مثلاً: 5.1',
        prefixIcon: Icon(Icons.battery_charging_full_outlined),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      validator: (v) {
        final s = (v ?? '').trim();
        if (s.isEmpty) return null;
        final n = double.tryParse(s);
        if (n == null) return 'القيمة غير صحيحة.';
        if (n <= 0 || n > 1000) return 'القيمة خارج النطاق المسموح.';
        return null;
      },
    );
  }
}

class _BatteryReserveField extends StatelessWidget {
  const _BatteryReserveField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'حد البطارية الأدنى % (اختياري)',
        hintText: '0 إلى 100',
        prefixIcon: Icon(Icons.shield_outlined),
      ),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      validator: (v) {
        final s = (v ?? '').trim();
        if (s.isEmpty) return null;
        final n = double.tryParse(s);
        if (n == null) return 'القيمة غير صحيحة.';
        if (n < 0 || n > 100) return 'القيمة خارج النطاق 0–100.';
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

// ─── Helpers ─────────────────────────────────────────────────────────

double? _parseDouble(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}
