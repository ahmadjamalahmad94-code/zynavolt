import 'package:flutter/material.dart';

/// Shared chart palette for the v77 advanced energy visualization.
///
/// Anchored to SolarDeye's existing visual language (indigo/violet
/// primary + mint energy + warm amber loads + sky blue battery), so the
/// chart, legend, and summary bars all speak the same color language.
/// Defining the palette in one place keeps the lines, the legend dots,
/// and the lower summary bars permanently in sync.
class ChartPalette {
  const ChartPalette._();

  // ── line / series colors ──────────────────────────────────────────
  /// الإنتاج — fresh solar / mint green.
  static const Color production = Color(0xFF10B981);

  /// الاستهلاك — warm amber load.
  static const Color consumption = Color(0xFFF59E0B);

  /// البطارية — calm sky/aqua blue.
  static const Color battery = Color(0xFF0EA5E9);

  /// الشبكة — soft violet / lavender.
  static const Color grid = Color(0xFF7C3AED);

  /// حالة الشحن — stronger blue / indigo line for the SOC reference.
  static const Color soc = Color(0xFF4338CA);

  /// Soft coral, reserved for missing-state or critical accents.
  static const Color critical = Color(0xFFEF4444);
}
