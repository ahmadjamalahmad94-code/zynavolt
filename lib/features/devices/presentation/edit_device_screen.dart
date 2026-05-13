import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../data/device_detail_models.dart';
import '../data/devices_repository.dart';

/// v51 — minimal device edit form for an existing subscriber device.
///
/// Field scope (verified against `_mobile_apply_device_fields` in
/// `web/app/blueprints/mobile_api.py:341`):
///
///   editable here:        name, plant_name, battery_capacity_kwh,
///                         battery_reserve_percent (via safe_settings)
///   NOT editable here:    is_active           — backend explicitly rejects
///                                                with `unsupported_field`;
///                                                use the delete action.
///                         device_type / provider — would re-resolve the
///                                                provider and break stored
///                                                credentials; out of scope.
///                         timezone            — backend supports it but
///                                                needs a catalog-validated
///                                                picker UI (follow-up gap).
///
/// The form pre-fills from the live [DeviceDetail] so the user only
/// types what they want to change. Empty values for plant_name clear
/// the field (matches backend behaviour: `plant_name[:120] or None`).
/// Empty battery fields are simply omitted from the request body so
/// the existing stored values are preserved.
class EditDeviceScreen extends ConsumerStatefulWidget {
  const EditDeviceScreen({super.key, required this.device});

  final DeviceDetail device;

  @override
  ConsumerState<EditDeviceScreen> createState() => _EditDeviceScreenState();
}

class _EditDeviceScreenState extends ConsumerState<EditDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _plantCtrl;
  late final TextEditingController _capacityCtrl;
  late final TextEditingController _reserveCtrl;
  bool _submitting = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.device.name);
    _plantCtrl = TextEditingController(text: widget.device.plantName);
    // Pre-fill the two safe-settings fields from the device's existing
    // `safeSettings` map so the user sees current values, not blank.
    final safe = widget.device.safeSettings;
    _capacityCtrl = TextEditingController(
        text: safe['battery_capacity_kwh'] ?? '');
    _reserveCtrl = TextEditingController(
        text: safe['battery_reserve_percent'] ?? '');
  }

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
    setState(() {
      _submitting = true;
      _serverError = null;
    });
    try {
      // Only send fields the user actually edited.
      final newName = _nameCtrl.text.trim();
      final newPlant = _plantCtrl.text.trim();
      final newCapacityText = _capacityCtrl.text.trim();
      final newReserveText = _reserveCtrl.text.trim();

      await ref.read(devicesRepositoryProvider).update(
            deviceId: widget.device.id,
            name: newName != widget.device.name ? newName : null,
            plantName:
                newPlant != widget.device.plantName ? newPlant : null,
            batteryCapacityKwh: _diffDouble(
              newCapacityText,
              widget.device.safeSettings['battery_capacity_kwh'],
            ),
            batteryReservePercent: _diffDouble(
              newReserveText,
              widget.device.safeSettings['battery_reserve_percent'],
            ),
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
        _serverError = 'تعذّر حفظ التعديلات: $e';
        _submitting = false;
      });
    }
  }

  /// Returns the new value as a double only when the user actually
  /// changed the text. An unchanged field returns `null` so the
  /// repository omits it from the PATCH body (preserving the
  /// server's existing value).
  double? _diffDouble(String text, String? existing) {
    final cur = (existing ?? '').trim();
    if (text == cur) return null;
    if (text.isEmpty) return null; // empty → omit (no clear semantics here)
    return double.tryParse(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(title: const Text('تعديل الجهاز')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HonestNote(deviceName: widget.device.name),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionTitle('الهوية'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        maxLength: 120,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'اسم الجهاز',
                          prefixIcon: Icon(Icons.edit_outlined),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'الاسم مطلوب.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _plantCtrl,
                        maxLength: 120,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'اسم المحطة / الموقع (اختياري)',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionTitle('إعدادات البطارية'),
                      const SizedBox(height: 4),
                      const Text(
                        'تُستخدم لحسابات الفائض الفعلي والتحليل الذكي على الخادم.',
                        style: TextStyle(
                          color: AppTheme.faintMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _capacityCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'سعة البطارية بالكيلوواط·ساعة (اختياري)',
                          hintText: 'مثلاً: 5.1',
                          prefixIcon:
                              Icon(Icons.battery_charging_full_outlined),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return null;
                          final n = double.tryParse(s);
                          if (n == null) return 'القيمة غير صحيحة.';
                          if (n < 0.1 || n > 1000) {
                            return 'القيمة خارج النطاق 0.1–1000.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _reserveCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'حد البطارية الأدنى % (اختياري)',
                          hintText: '0 إلى 100',
                          prefixIcon: Icon(Icons.shield_outlined),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return null;
                          final n = double.tryParse(s);
                          if (n == null) return 'القيمة غير صحيحة.';
                          if (n < 0 || n > 100) {
                            return 'القيمة خارج النطاق 0–100.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                if (_serverError != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _serverError!),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: AppTheme.formControlHeight,
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
                    label: const Text('حفظ التعديلات'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          color: AppTheme.ink,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      );
}

class _HonestNote extends StatelessWidget {
  const _HonestNote({required this.deviceName});
  final String deviceName;

  @override
  Widget build(BuildContext context) {
    final subject = deviceName.isNotEmpty ? deviceName : 'هذا الجهاز';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.indigoSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.indigoBright.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              color: AppTheme.indigoPrimary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تعديل بيانات «$subject». بيانات الاتصال بالمزوّد والمنطقة '
              'الزمنية والتفعيل تُغيَّر من تدفقات مخصّصة منفصلة.',
              style: const TextStyle(
                color: AppTheme.indigoPrimary,
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.danger,
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
