import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/weather_models.dart';
import '../data/weather_repository.dart';

/// v63 — subscriber-facing weather tab.
///
/// Consumes `GET /api/v1/devices/<id>/weather` (v62). Honest by
/// construction: when the backend says `available=false`, the screen
/// shows a calm explanation card and **nothing else** — no fabricated
/// temperatures, no placeholder sunrise/sunset, no fake forecast.
///
/// Phase-1 scope (mirrors the v62 contract + v61 audit):
///   * Current header (icon + temp + condition_ar + wind / cloud).
///   * Sun row (sunrise / sunset, with effective sunset caption).
///   * Next-hour insight card (advice + solar rating).
///   * Three day-part chips (morning / noon / afternoon).
///   * Timeline strip (horizontal scroll of `timeline[]` entries).
///   * `generated_at` footer.
///
/// Deliberately NOT in v63:
///   * Pre-sunset prediction / smart energy forecast (energy-coupled).
///   * Multi-day forecast (backend currently fetches 2 days).
///   * Weather notification preferences (admin-scoped today).
class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(weatherProvider);

    // v100 — gradient backdrop for visual continuity.
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الطقس'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.pageBackdropGradient),
        child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(weatherProvider);
            await ref.read(weatherProvider.future);
          },
          child: snap.when(
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 48),
              children: const [
                AppLoading(message: 'جارٍ تحميل بيانات الطقس...'),
              ],
            ),
            error: (err, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                AppErrorState(
                  error: err is ApiException
                      ? err
                      : ApiException(
                          message: 'تعذّر تحميل بيانات الطقس.',
                          kind: ApiErrorKind.unknown,
                        ),
                  onRetry: () => ref.invalidate(weatherProvider),
                ),
              ],
            ),
            data: (data) {
              if (data == null) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: const [_NoDeviceCard()],
                );
              }
              return _WeatherBody(snapshot: data);
            },
          ),
        ),
        ),  // close DecoratedBox child SafeArea
      ),
    );
  }
}

// ─── Body ────────────────────────────────────────────────────────────

class _WeatherBody extends StatelessWidget {
  const _WeatherBody({required this.snapshot});

  final WeatherSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (!snapshot.available) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _DeviceHeader(device: snapshot.device),
          const SizedBox(height: 12),
          _UnavailableCard(
            reason: snapshot.reason,
            backendMessage: snapshot.message,
          ),
          const SizedBox(height: 12),
          _GeneratedAtFooter(generatedAt: snapshot.generatedAt),
          const SizedBox(height: 24),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _DeviceHeader(device: snapshot.device),
        const SizedBox(height: 12),
        if (snapshot.current != null)
          _CurrentCard(current: snapshot.current!),
        if (snapshot.sun != null) ...[
          const SizedBox(height: 12),
          _SunRow(sun: snapshot.sun!),
        ],
        if (snapshot.nextHour != null) ...[
          const SizedBox(height: 12),
          _NextHourCard(slot: snapshot.nextHour!),
        ],
        if (snapshot.dayParts != null) ...[
          const SizedBox(height: 12),
          _DayPartsCard(dayParts: snapshot.dayParts!),
        ],
        if (snapshot.timeline.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TimelineCard(timeline: snapshot.timeline),
        ],
        const SizedBox(height: 12),
        _GeneratedAtFooter(generatedAt: snapshot.generatedAt),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────

class _DeviceHeader extends StatelessWidget {
  const _DeviceHeader({required this.device});
  final WeatherDevice device;

  @override
  Widget build(BuildContext context) {
    final hasName = device.name.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.indigoSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.indigoBright.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_outlined,
              color: AppTheme.indigoPrimary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasName
                  ? 'حالة الطقس الحالية لجهاز: ${device.name}'
                  : 'حالة الطقس الحالية',
              style: const TextStyle(
                color: AppTheme.indigoPrimary,
                fontSize: 12.5,
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

// ─── Current conditions ──────────────────────────────────────────────

class _CurrentCard extends StatelessWidget {
  const _CurrentCard({required this.current});
  final WeatherCurrent current;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                current.icon.isNotEmpty ? current.icon : '🌤️',
                style: const TextStyle(fontSize: 44, height: 1.0),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatTemperature(current.temperatureC),
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current.conditionAr.isNotEmpty
                          ? current.conditionAr
                          : 'حالة الطقس غير متاحة',
                      style: const TextStyle(
                        color: AppTheme.softInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.cloud_outlined,
                label: 'الغيوم',
                value: _formatPercent(current.cloudCoverPercent),
              ),
              _MetaChip(
                icon: Icons.air_outlined,
                label: 'الرياح',
                value: _formatWind(current.windSpeed),
              ),
              _MetaChip(
                icon: Icons.water_drop_outlined,
                label: 'احتمالية المطر',
                value: _formatPercent(current.precipitationProbabilityPercent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Sun row ─────────────────────────────────────────────────────────

class _SunRow extends StatelessWidget {
  const _SunRow({required this.sun});
  final WeatherSun sun;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(label: 'الشروق والغروب'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SunPill(
                  icon: Icons.wb_twilight_outlined,
                  label: 'الشروق',
                  value: sun.sunriseTime ?? '—',
                  tone: AppTheme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SunPill(
                  icon: Icons.nightlight_outlined,
                  label: 'الغروب',
                  value: sun.sunsetTime ?? '—',
                  tone: AppTheme.indigoPrimary,
                ),
              ),
            ],
          ),
          if (sun.effectiveSunsetTime != null &&
              sun.effectiveSunsetTime!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'الإنتاج الشمسي الفعّال يقترب من ${sun.effectiveSunsetTime}.',
              style: const TextStyle(
                color: AppTheme.faintMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SunPill extends StatelessWidget {
  const _SunPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: tone, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: tone,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Next-hour insight ───────────────────────────────────────────────

class _NextHourCard extends StatelessWidget {
  const _NextHourCard({required this.slot});
  final WeatherSlot slot;

  @override
  Widget build(BuildContext context) {
    final timeLabel =
        slot.displayTime.isNotEmpty ? slot.displayTime : 'الساعة القادمة';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _SectionTitle(label: 'الساعة القادمة'),
              const Spacer(),
              Text(
                timeLabel,
                style: const TextStyle(
                  color: AppTheme.faintMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                slot.icon.isNotEmpty ? slot.icon : '🌤️',
                style: const TextStyle(fontSize: 32, height: 1.0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.conditionAr.isNotEmpty
                          ? slot.conditionAr
                          : '—',
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTemperature(slot.temperature),
                      style: const TextStyle(
                        color: AppTheme.softInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (slot.solarRating.isNotEmpty)
            _SlotBadge(label: slot.solarRating),
          if (slot.advice.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              slot.advice,
              style: const TextStyle(
                color: AppTheme.softInk,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.65,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Day-parts (morning / noon / afternoon) ──────────────────────────

class _DayPartsCard extends StatelessWidget {
  const _DayPartsCard({required this.dayParts});
  final WeatherDayParts dayParts;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];
    void add(String label, WeatherSlot? slot) {
      if (slot == null) return;
      cards.add(_DayPartChip(label: label, slot: slot));
    }

    add('الصباح', dayParts.morning);
    add('الظهر', dayParts.noon);
    add('بعد الظهر', dayParts.afternoon);

    if (cards.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(label: 'فترات اليوم'),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i < cards.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DayPartChip extends StatelessWidget {
  const _DayPartChip({required this.label, required this.slot});
  final String label;
  final WeatherSlot slot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.softBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.faintMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            slot.icon.isNotEmpty ? slot.icon : '🌤️',
            style: const TextStyle(fontSize: 22, height: 1.0),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTemperature(slot.temperature),
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            slot.conditionAr.isNotEmpty ? slot.conditionAr : '—',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.softInk,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline strip ──────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.timeline});
  final List<WeatherSlot> timeline;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(label: 'مخطط اليوم'),
          const SizedBox(height: 10),
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: timeline.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _TimelineTile(slot: timeline[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.slot});
  final WeatherSlot slot;

  @override
  Widget build(BuildContext context) {
    final time = slot.displayTime;
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.softBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            time.isNotEmpty ? time : '—',
            style: const TextStyle(
              color: AppTheme.faintMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            slot.icon.isNotEmpty ? slot.icon : '🌤️',
            style: const TextStyle(fontSize: 22, height: 1.0),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTemperature(slot.temperature),
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatPercent(slot.cloudCover),
            style: const TextStyle(
              color: AppTheme.softInk,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (slot.solarRating.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              slot.solarRating,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.indigoPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Unavailable / no-device cards ───────────────────────────────────

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.reason, required this.backendMessage});

  final String? reason;
  final String? backendMessage;

  String get _title {
    switch (reason) {
      case 'station_coords_unavailable':
        return 'إحداثيات الجهاز غير متوفرة';
      case 'weather_unreachable':
        return 'تعذّر الوصول إلى خدمة الطقس';
      default:
        return 'بيانات الطقس غير متوفرة';
    }
  }

  String get _detail {
    switch (reason) {
      case 'station_coords_unavailable':
        return 'لم نتمكّن من تحديد موقع المحطة من بيانات المزوّد بعد. '
            'تحقق من اكتمال إعداد الجهاز ومن أنه قام بأوّل مزامنة ناجحة.';
      case 'weather_unreachable':
        return 'خدمة الطقس الخارجية لا تستجيب في الوقت الحالي. '
            'حاول مرة أخرى بعد لحظات.';
      default:
        return backendMessage?.isNotEmpty == true
            ? backendMessage!
            : 'سيتوفّر العرض فور توفّر بيانات الطقس.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              color: AppTheme.faintMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _detail,
                  style: const TextStyle(
                    color: AppTheme.softInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoDeviceCard extends StatelessWidget {
  const _NoDeviceCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Text(
            'لا يوجد جهاز محدّد',
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'لعرض الطقس، أضف جهازاً واحداً على الأقل من تبويب الأجهزة، '
            'ثم اختره كجهاز فعّال.',
            style: TextStyle(
              color: AppTheme.softInk,
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

// ─── Atoms ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.faintMuted, size: 14),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppTheme.faintMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SlotBadge extends StatelessWidget {
  const _SlotBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.indigoSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.indigoBright.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.indigoPrimary,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _GeneratedAtFooter extends StatelessWidget {
  const _GeneratedAtFooter({required this.generatedAt});
  final String generatedAt;

  @override
  Widget build(BuildContext context) {
    if (generatedAt.isEmpty) return const SizedBox.shrink();
    // The backend ships an ISO timestamp; we surface just the HH:MM
    // portion when it parses, otherwise the raw string. We never
    // localize aggressively — keep it honest and read-only.
    String label = generatedAt;
    if (generatedAt.length >= 16) {
      label = generatedAt.substring(11, 16);
    }
    return Center(
      child: Text(
        'آخر تحديث: $label',
        style: const TextStyle(
          color: AppTheme.faintMuted,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Formatters ──────────────────────────────────────────────────────

String _formatTemperature(double? c) {
  if (c == null) return '--°';
  return '${c.toStringAsFixed(1)}°';
}

String _formatPercent(double? p) {
  if (p == null) return '--';
  return '${p.toStringAsFixed(0)}%';
}

String _formatWind(double? w) {
  if (w == null) return '--';
  return '${w.toStringAsFixed(1)} km/h';
}
