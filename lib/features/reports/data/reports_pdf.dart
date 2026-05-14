import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'reports_models.dart';

/// v102d — on-device PDF generator for the Reports screen.
///
/// Builds a single A4 page that mirrors the report card content
/// (energy totals + source shares + derived metrics) in Arabic,
/// using the bundled Alexandria font for proper shaping.
///
/// Output is the raw bytes ready to hand to `printing`'s share /
/// save dialog. No I/O — the caller decides where the bytes go
/// (system share sheet, file save, print preview).
class ReportsPdfBuilder {
  ReportsPdfBuilder._();

  /// Build the PDF and return its bytes.
  ///
  /// [snapshot] — the live report payload (`/reports/summary`).
  /// [deviceName] — short display name of the active device,
  ///                used in the header. Pass empty if unknown.
  static Future<Uint8List> generate({
    required ReportsSnapshot snapshot,
    required String deviceName,
  }) async {
    // Load Arabic-shaped fonts from the asset bundle. We bundle
    // Alexandria already for the in-app typography; reuse it for
    // the PDF so the output reads like the screen.
    final regularData =
        await rootBundle.load('assets/fonts/Alexandria-Regular.ttf');
    final boldData =
        await rootBundle.load('assets/fonts/Alexandria-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);

    final doc = pw.Document(
      theme: theme,
      title: 'Zynavolt — تقرير الطاقة',
      author: 'Zynavolt',
      subject: snapshot.titleHint,
    );

    final s = snapshot.summary;
    final viewLabel = snapshot.view == 'month' ? 'تقرير شهري' : 'تقرير يومي';
    final generated = _formatIsoToLocal(snapshot.generatedAt);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.fromLTRB(28, 32, 28, 32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _header(
                viewLabel: viewLabel,
                titleHint: snapshot.titleHint,
                deviceName: deviceName,
              ),
              pw.SizedBox(height: 18),
              if (snapshot.empty)
                _emptyBanner()
              else ...[
                _totalsBlock(s),
                pw.SizedBox(height: 14),
                _sharesBlock(s),
                pw.SizedBox(height: 14),
                _metricsBlock(s),
              ],
              pw.Spacer(),
              _footer(generated: generated),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // ── Layout helpers ─────────────────────────────────────────────────

  static pw.Widget _header({
    required String viewLabel,
    required String titleHint,
    required String deviceName,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [PdfColors.indigo700, PdfColors.indigo900],
          begin: pw.Alignment.topRight,
          end: pw.Alignment.bottomLeft,
        ),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Zynavolt',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white.shade(0.18),
                  borderRadius: pw.BorderRadius.circular(999),
                ),
                child: pw.Text(
                  viewLabel,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'تقرير الطاقة',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (titleHint.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              titleHint,
              style: pw.TextStyle(
                color: PdfColor.fromInt(0xFFCBD5FF),
                fontSize: 12,
              ),
            ),
          ],
          if (deviceName.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                pw.Text(
                  'الجهاز:',
                  style: pw.TextStyle(
                    color: PdfColor.fromInt(0xFFCBD5FF),
                    fontSize: 11,
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Text(
                  deviceName,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _totalsBlock(ReportsSummary s) {
    return _Block(
      title: 'إجماليات الطاقة',
      rows: [
        _BlockRow(
          label: 'الإنتاج',
          value: _fmtKwh(s.productionKwh),
          tone: PdfColor.fromInt(0xFFF59E0B),
        ),
        _BlockRow(
          label: 'الاستهلاك',
          value: _fmtKwh(s.consumptionKwh),
          tone: PdfColor.fromInt(0xFF6366F1),
        ),
        _BlockRow(
          label: 'شحن البطارية',
          value: _fmtKwh(s.batteryInKwh),
          tone: PdfColor.fromInt(0xFF10B981),
        ),
        _BlockRow(
          label: 'الاعتماد على الشبكة',
          value: _fmtKwh(s.gridInKwh),
          tone: PdfColor.fromInt(0xFF64748B),
        ),
      ],
    ).build();
  }

  static pw.Widget _sharesBlock(ReportsSummary s) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'حصص مصادر الطاقة',
            style: pw.TextStyle(
              color: PdfColor.fromInt(0xFF0F172A),
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'النسبة المئوية لما غذّى المنزل خلال الفترة.',
            style: pw.TextStyle(
              color: PdfColor.fromInt(0xFF64748B),
              fontSize: 10,
            ),
          ),
          pw.SizedBox(height: 10),
          _shareBar(
            label: 'حصة الطاقة الشمسية',
            percent: s.solarSharePercent,
            tone: PdfColor.fromInt(0xFFF59E0B),
          ),
          pw.SizedBox(height: 8),
          _shareBar(
            label: 'حصة البطارية',
            percent: s.batterySharePercent,
            tone: PdfColor.fromInt(0xFF10B981),
          ),
          pw.SizedBox(height: 8),
          _shareBar(
            label: 'حصة الشبكة',
            percent: s.gridSharePercent,
            tone: PdfColor.fromInt(0xFF64748B),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            height: 1,
            color: PdfColor.fromInt(0xFFEEF0F4),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Text(
                'الاكتفاء الذاتي',
                style: pw.TextStyle(
                  color: PdfColor.fromInt(0xFF334155),
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                '${s.selfSufficiencyPercent.toStringAsFixed(1)}%',
                style: pw.TextStyle(
                  color: PdfColor.fromInt(0xFF4338CA),
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _shareBar({
    required String label,
    required double percent,
    required PdfColor tone,
  }) {
    final clamped = percent.clamp(0.0, 100.0);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                color: PdfColor.fromInt(0xFF334155),
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Spacer(),
            pw.Text(
              '${percent.toStringAsFixed(1)}%',
              style: pw.TextStyle(
                color: tone,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.ClipRRect(
          horizontalRadius: 999,
          verticalRadius: 999,
          child: pw.SizedBox(
            height: 6,
            child: pw.Row(
              children: [
                if (clamped > 0)
                  pw.Expanded(
                    flex: clamped.round(),
                    child: pw.Container(color: tone),
                  ),
                if (clamped < 100)
                  pw.Expanded(
                    flex: (100 - clamped).round(),
                    child: pw.Container(
                      color: PdfColor.fromInt(0xFFEEF0F4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _metricsBlock(ReportsSummary s) {
    return _Block(
      title: 'مؤشرات إضافية',
      rows: [
        _BlockRow(
          label: 'متوسط الحمل',
          value: '${s.averageLoadW.toStringAsFixed(1)} W',
          tone: PdfColor.fromInt(0xFF6366F1),
        ),
        _BlockRow(
          label: 'الفائض الشمسي',
          value: _fmtKwh(s.solarSurplusKwh),
          tone: PdfColor.fromInt(0xFFF59E0B),
        ),
      ],
    ).build();
  }

  static pw.Widget _emptyBanner() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFFF7ED),
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFFED7AA)),
      ),
      child: pw.Text(
        'لا توجد قراءات لهذه الفترة لاحتساب التقرير. جرّب تاريخاً آخر '
        'أو انتظر تجميع قراءات إضافية.',
        style: pw.TextStyle(
          color: PdfColor.fromInt(0xFF92400E),
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _footer({required String generated}) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColor.fromInt(0xFFE5E7EB)),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'Zynavolt · zynavolt.com',
            style: pw.TextStyle(
              color: PdfColor.fromInt(0xFF94A3B8),
              fontSize: 9,
            ),
          ),
          pw.Spacer(),
          pw.Text(
            'تاريخ التوليد: $generated',
            style: pw.TextStyle(
              color: PdfColor.fromInt(0xFF94A3B8),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtKwh(double v) => '${v.toStringAsFixed(2)} kWh';

  static String _formatIsoToLocal(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '${dt.year}-$m-$d $hh:$mm';
    } catch (_) {
      return iso;
    }
  }
}

/// Small grouping primitive for the PDF — title + a vertical list
/// of label/value rows with a coloured pip on the leading side.
class _Block {
  _Block({required this.title, required this.rows});
  final String title;
  final List<_BlockRow> rows;

  pw.Widget build() {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              color: PdfColor.fromInt(0xFF0F172A),
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          for (final r in rows) ...[
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                pw.Container(
                  width: 10,
                  height: 10,
                  decoration: pw.BoxDecoration(
                    color: r.tone,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    r.label,
                    style: pw.TextStyle(
                      color: PdfColor.fromInt(0xFF334155),
                      fontSize: 11.5,
                    ),
                  ),
                ),
                pw.Text(
                  r.value,
                  style: pw.TextStyle(
                    color: PdfColor.fromInt(0xFF0F172A),
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BlockRow {
  _BlockRow({required this.label, required this.value, required this.tone});
  final String label;
  final String value;
  final PdfColor tone;
}
