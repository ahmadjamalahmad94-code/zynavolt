import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/state/app_session.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../devices/data/device_detail_repository.dart';
import '../../devices/data/devices_repository.dart';
import '../../devices/presentation/add_device_screen.dart';
import '../../devices/presentation/device_setup_screen.dart';
import '../data/onboarding_models.dart';
import '../data/onboarding_repository.dart';

/// v53 — first-run subscriber onboarding flow.
///
/// Orchestrates the existing v48 add-device, v49 provider-setup, and
/// v50 sync-now surfaces into a single staged checklist. The screen
/// reads `/api/mobile/onboarding` for the source of truth on what's
/// left, and re-fetches that state after each substep so the next
/// visible stage is derived from fresh backend data — there is no
/// optimistic client-side step pointer.
///
/// Completion is marked by `POST /api/mobile/onboarding` with
/// `{onboarding_completed: true}`. The router redirect then sees the
/// refreshed [AuthUser.onboardingCompleted] flag and stops rerouting
/// the user back here.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _finishing = false;
  bool _syncing = false;
  bool _resolvingSetup = false;
  String? _actionError;

  Future<void> _refresh() async {
    ref.invalidate(onboardingStateProvider);
    // Wait until the new state resolves so the user sees the next
    // stage open rather than a flicker back to loading.
    await ref.read(onboardingStateProvider.future);
  }

  Future<void> _pushAddDevice() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
    );
    if (!mounted) return;
    if (added == true) {
      await _refresh();
    }
  }

  Future<void> _pushProviderSetup(int deviceId) async {
    if (_resolvingSetup) return;
    setState(() {
      _resolvingSetup = true;
      _actionError = null;
    });
    try {
      // Setup screen takes a full DeviceDetail — fetch it once so the
      // existing screen sees the same data shape it expects when
      // launched from the device-detail screen.
      final snapshot =
          await ref.read(deviceDetailProvider(deviceId).future);
      if (!mounted) return;
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => DeviceSetupScreen(device: snapshot.device),
        ),
      );
      if (!mounted) return;
      if (saved == true) {
        ref.invalidate(deviceDetailProvider(deviceId));
        await _refresh();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _actionError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = 'تعذّر فتح شاشة الإعداد: $e');
    } finally {
      if (mounted) setState(() => _resolvingSetup = false);
    }
  }

  Future<void> _triggerSyncNow(int deviceId) async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _actionError = null;
    });
    try {
      await ref
          .read(devicesRepositoryProvider)
          .submitSyncNow(deviceId: deviceId);
      if (!mounted) return;
      ref.invalidate(deviceDetailProvider(deviceId));
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      // Honest copy — sync_failed / setup_not_ready are real states the
      // user can encounter; we surface the backend message rather than
      // pretending success.
      setState(() => _actionError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = 'تعذّر تشغيل المزامنة: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _openProfile() async {
    // Profile editor lives at /profile and is fully reused from v51.
    // We `push` so the back arrow returns to onboarding rather than
    // dumping the user into /home before onboarding is complete.
    await context.push(AppRoutes.profile);
    if (!mounted) return;
    // The session controller has its own refresh path after profile
    // edits, but we also refresh onboarding state so the location
    // banner clears once the user fills country/city/timezone.
    await ref.read(appSessionProvider.notifier).refreshMe();
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _actionError = null;
    });
    try {
      await ref.read(onboardingRepositoryProvider).markComplete();
      // Refresh /auth/me so the router redirect sees the new
      // `onboarding.completed=true` flag and stops looping us back.
      await ref.read(appSessionProvider.notifier).refreshMe();
      if (!mounted) return;
      context.go(AppRoutes.home);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _finishing = false;
        _actionError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _finishing = false;
        _actionError = 'تعذّر إنهاء الإعداد: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider);
    final user = session.user;
    final firstName = (user?.fullName.trim().isNotEmpty ?? false)
        ? user!.fullName.trim().split(' ').first
        : (user?.username ?? '');

    final state = ref.watch(onboardingStateProvider);

    // v100 — gradient backdrop for visual continuity.
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('البدء مع Zynavolt'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          TextButton(
            onPressed: _finishing ? null : _finish,
            child: const Text('تخطي'),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.pageBackdropGradient),
        child: SafeArea(
        child: state.when(
          loading: () => const AppLoading(message: 'جارٍ تحضير شاشة البدء...'),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: AppErrorState(
              error: err is ApiException
                  ? err
                  : ApiException(
                      message: 'تعذّر تحميل حالة البدء.',
                      kind: ApiErrorKind.unknown,
                    ),
              onRetry: () => ref.invalidate(onboardingStateProvider),
            ),
          ),
          data: (snap) => _buildBody(snap, firstName),
        ),
      ),  // close DecoratedBox child SafeArea (v100)
      ),
    );
  }

  Widget _buildBody(OnboardingState snap, String firstName) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _WelcomeCard(firstName: firstName),
          const SizedBox(height: 12),
          _StageCard(
            index: 1,
            title: 'استكمل بيانات حسابك',
            description:
                'نحتاج البلد والمدينة والمنطقة الزمنية لعرض الإنتاج بتوقيتك الصحيح.',
            done: !snap.needsProfileLocation,
            actionLabel: 'افتح الملف الشخصي',
            actionIcon: Icons.person_outline,
            onAction: _openProfile,
            doneLabel: 'تم — بيانات الموقع جاهزة.',
          ),
          const SizedBox(height: 12),
          _StageCard(
            index: 2,
            title: 'أضف جهازك الأول',
            description: snap.needsDeviceLink
                ? 'سجّل العاكس / الجهاز الذي ترغب بمتابعته. تختار المزوّد '
                    'وتدخل اسم الجهاز فقط في هذه الخطوة.'
                : 'لديك ${snap.totalDevices} جهاز/أجهزة مسجّلة. يمكنك '
                    'إضافة المزيد لاحقاً من تبويب «الأجهزة».',
            done: !snap.needsDeviceLink,
            actionLabel: snap.needsDeviceLink ? 'إضافة جهاز' : 'إضافة جهاز آخر',
            actionIcon: Icons.add_circle_outline,
            onAction: _pushAddDevice,
            doneLabel: 'تم — تم تسجيل جهاز واحد على الأقل.',
          ),
          if (snap.needsProviderSetup) ...[
            const SizedBox(height: 12),
            _StageCard(
              index: 3,
              title: 'أكمل بيانات الاتصال بالمزوّد',
              description:
                  'الجهاز «${snap.currentDeviceName}» بحالة «بحاجة إلى إعداد». '
                  'أدخل بيانات الاتصال (مثل البريد، كلمة المرور، أو مفتاح API) '
                  'كي يبدأ التطبيق بقراءة البيانات من المزوّد.',
              done: false,
              actionLabel:
                  _resolvingSetup ? 'جارٍ الفتح...' : 'إكمال إعداد المزوّد',
              actionIcon: Icons.settings_input_component_outlined,
              onAction: _resolvingSetup || snap.selectedDeviceId == null
                  ? null
                  : () => _pushProviderSetup(snap.selectedDeviceId!),
              doneLabel: '',
            ),
          ],
          if (snap.needsFirstSync) ...[
            const SizedBox(height: 12),
            _StageCard(
              index: snap.needsProviderSetup ? 4 : 3,
              title: 'جرّب المزامنة الأولى',
              description:
                  'بيانات الإعداد محفوظة. حاول المزامنة الآن للتأكد من أن '
                  'الجهاز يصل إلى المزوّد بشكل صحيح. الحالة الحالية: '
                  '«${snap.currentConnectionStatus}».',
              done: false,
              actionLabel: _syncing ? 'جارٍ المزامنة...' : 'تشغيل المزامنة الآن',
              actionIcon: Icons.sync,
              onAction: _syncing || snap.selectedDeviceId == null
                  ? null
                  : () => _triggerSyncNow(snap.selectedDeviceId!),
              doneLabel: '',
            ),
          ],
          if (_actionError != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _actionError!),
          ],
          const SizedBox(height: 18),
          _FinishButton(
            busy: _finishing,
            label: snap.needsDeviceLink
                ? 'إنهاء الإعداد لاحقاً'
                : 'تم! ابدأ الاستخدام',
            onPressed: _finish,
          ),
          const SizedBox(height: 8),
          const _FinishNote(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.firstName});
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final hello = firstName.isNotEmpty ? 'أهلاً $firstName 👋' : 'أهلاً بك 👋';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppTheme.indigoPrimary, AppTheme.indigoBright],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hello,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'سنرافقك في أربع خطوات قصيرة لربط جهازك الأول وعرض الإنتاج '
            'بشكل صحيح. يمكنك الإنهاء في أي وقت والعودة لاحقاً.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.index,
    required this.title,
    required this.description,
    required this.done,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    required this.doneLabel,
  });

  final int index;
  final String title;
  final String description;
  final bool done;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  /// Caption shown under the title when [done] is true. Empty string
  /// hides the row entirely (some stages don't have a stable "done"
  /// state — e.g. the sync stage disappears once successful, so there
  /// is no need to render a "done" caption for it).
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _StageBadge(index: index, done: done),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (done)
                const Icon(Icons.check_circle,
                    color: AppTheme.success, size: 22),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: AppTheme.softInk,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.75,
            ),
          ),
          if (done && doneLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              doneLabel,
              style: const TextStyle(
                color: AppTheme.success,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: AppTheme.formControlHeight,
            child: done
                ? OutlinedButton.icon(
                    onPressed: onAction,
                    icon: Icon(actionIcon, size: 18),
                    label: Text(actionLabel),
                  )
                : FilledButton.icon(
                    onPressed: onAction,
                    icon: Icon(actionIcon, size: 18),
                    label: Text(actionLabel),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.index, required this.done});
  final int index;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final tone = done ? AppTheme.success : AppTheme.indigoPrimary;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      alignment: Alignment.center,
      child: Text(
        '$index',
        style: TextStyle(
          color: tone,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FinishButton extends StatelessWidget {
  const _FinishButton({
    required this.busy,
    required this.label,
    required this.onPressed,
  });
  final bool busy;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTheme.formControlHeight + 4,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.flag_outlined, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _FinishNote extends StatelessWidget {
  const _FinishNote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'إنهاء الإعداد لا يُلغي خطواتك. تستطيع متابعة الإعداد لاحقاً من تبويب '
      '«الأجهزة» أو من الملف الشخصي.',
      style: TextStyle(
        color: AppTheme.faintMuted,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        height: 1.7,
      ),
      textAlign: TextAlign.center,
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
