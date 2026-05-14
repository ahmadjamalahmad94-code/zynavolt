import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'statistics_models.dart';

/// v102d — on-device PDF generator for the Statistics screen.
///
/// Mirrors the on-screen layout: header + totals card + per-bucket
/// table (hourly for `view=day`, daily for `view=month`). Renders
/// in Arabic via the bundled Alexandria font and supports multi-
/// page output when a month-view bucket list grows tall.
class StatisticsPdfBuilder {
  StatisticsPdfBuilder._();

  static Future<Uint8List> generate({
    required StatisticsSnapshot snapshot,
    required String deviceName,
  }) async {
    final regularData =
        await rootBundle.load('assets/fonts/Alexandria-Regular.ttf');
    final boldData =
        await rootBundle.load('assets/fonts/Alexandria-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);

    final doc = pw.Document(
      theme: theme,
      title: 'Zynavolt — تقرير الإحصاءات',
      author: 'Zynavolt',
      subject: snapshot.titleHint,
    );

    final t = snapshot.totals;
    final b = snapshot.buckets;
    final viewLabel =
        snapshot.view == 'month' ? 'إحصاءات شهرية' : 'إحصاءات يومية';
    final unitLabel = snapshot.view == 'day' ? 'كل ساعة' : 'كل يوم';
    final generated = _formatIsoToLocal(snapshot.generatedAt);

    // Build header + summary as a single block, then bucket rows
    // streamed as a multi-page list so a 31-day month spread fits
    // gracefully across page breaks.
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.fromLTRB(28, 32, 28, 32),
        header: (context) {
          if (context.pageNumber == 1) return pw.SizedBox();
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              'Zynavolt · $viewLabel',
              style: pw.TextStyle(
                color: PdfColor.fromInt(0xFF94A3B8),
                fontSize: 9,
              ),
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColor.fromInt(0xFFE5E7EB)),
              ),
            ),
            child: pw.Row(
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
                  'صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: pw.TextStyle(
                    color: PdfColor.fromInt(0xFF94A3B8),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            _header(
              viewLabel: viewLabel,
              titleHint: snapshot.titleHint,
              deviceName: deviceName,
            ),
            pw.SizedBox(height: 18),
            if (snapshot.empty)
              _emptyBanner()
            else ...[
              _totalsCard(t),
              pw.SizedBox(height: 14),
              _bucketsCard(buckets: b, unitLabel: unitLabel),
            ],
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6),
              child: pw.Text(
                'تاريخ التوليد: $generated',
                style: pw.TextStyle(
                  color: PdfColor.fromInt(0xFF94A3B8),
                  fontSize: 9,
                ),
              ),
            ),
          ];
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
            'تقرير الإحصاءات',
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

  static pw.Widget _totalsCard(StatisticsTotals t) {
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
            'إجماليات الفترة',
            style: pw.TextStyle(
              color: PdfColor.fromInt(0xFF0F172A),
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _totalRow(
            label: 'الإنتاج',
            value: '${t.productionKwh.toStringAsFixed(2)} kWh',
            tone: PdfColor.fromInt(0xFFF59E0B),
          ),
          _totalRow(
            label: 'الاستهلاك',
            value: '${t.consumptionKwh.toStringAsFixed(2)} kWh',
            tone: PdfColor.fromInt(0xFF6366F1),
          ),
          _totalRow(
            label: 'شحن البطارية',
            value: '${t.batteryInKwh.toStringAsFixed(2)} kWh',
            tone: PdfColor.fromInt(0xFF10B981),
          ),
          _totalRow(
            label: 'استيراد الشبكة',
            value: '${t.gridInKwh.toStringAsFixed(2)} kWh',
            tone: PdfColor.fromInt(0xFF64748B),
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 1, color: PdfColor.fromInt(0xFFEEF0F4)),
          pw.SizedBox(height: 8),
          _metaRow(
            label: 'متوسط الشحنة',
            value: '${t.avgBatterySocPercent.toStringAsFixed(1)}%',
          ),
          _metaRow(
            label: 'ذروة الإنتاج',
            value: '${t.maxSolarW.toStringAsFixed(0)} W',
          ),
          _metaRow(label: 'عدد القراءات', value: '${t.samples}'),
          if (t.dataGaps > 0)
            _metaRow(label: 'فجوات البيانات', value: '${t.dataGaps}'),
        ],
      ),
    );
  }

  static pw.Widget _totalRow({
    required String label,
    required String value,
    required PdfColor tone,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.Container(
            width: 10,
            height: 10,
            decoration: pw.BoxDecoration(
              color: tone,
              borderRadius: pw.BorderRadius.circular(3),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                color: PdfColor.fromInt(0xFF334155),
                fontSize: 11.5,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: PdfColor.fromInt(0xFF0F172A),
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaRow({required String label, required String value}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                color: PdfColor.fromInt(0xFF64748B),
                fontSize: 11,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: PdfColor.fromInt(0xFF0F172A),
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _bucketsCard({
    required StatisticsBuckets buckets,
    required String unitLabel,
  }) {
    final count = [
      buckets.labels.length,
      buckets.productionKwh.length,
      buckets.consumptionKwh.length,
    ].reduce((a, b) => a < b ? a : b);

    if (count == 0) {
      return pw.SizedBox();
    }

    var totalProd = 0.0;
    var totalCons = 0.0;
    for (var i = 0; i < count; i++) {
      totalProd += buckets.productionKwh[i];
      totalCons += buckets.consumptionKwh[i];
    }

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
          pw.Row(
            children: [
              pw.Text(
                'التفاصيل',
                style: pw.TextStyle(
                  color: PdfColor.fromInt(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                unitLabel,
                style: pw.TextStyle(
                  color: PdfColor.fromInt(0xFF64748B),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.symmetric(
              inside: pw.BorderSide(
                color: PdfColor.fromInt(0xFFEEF0F4),
                width: 0.6,
              ),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF7F9FC),
                ),
                children: [
                  _th('الفترة'),
                  _th('الإنتاج (kWh)', align: pw.TextAlign.center),
                  _th('الاستهلاك (kWh)', align: pw.TextAlign.center),
                ],
              ),
              for (var i = 0; i < count; i++)
                pw.TableRow(
                  children: [
                    _td(buckets.labels[i]),
                    _td(
                      buckets.productionKwh[i].toStringAsFixed(2),
                      align: pw.TextAlign.center,
                    ),
                    _td(
                      buckets.consumptionKwh[i].toStringAsFixed(2),
                      align: pw.TextAlign.center,
                    ),
                  ],
                ),
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF7F9FC),
                ),
                children: [
                  _th('المجموع'),
                  _th(
                    totalProd.toStringAsFixed(2),
                    align: pw.TextAlign.center,
                  ),
                  _th(
                    totalCons.toStringAsFixed(2),
                    align: pw.TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _th(String label, {pw.TextAlign? align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        label,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColor.fromInt(0xFF334155),
          fontSize: 10.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _td(String value, {pw.TextAlign? align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        value,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColor.fromInt(0xFF0F172A),
          fontSize: 10.5,
        ),
      ),
    );
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
        'لا توجد قراءات كافية لهذه الفترة. جرّب تاريخاً آخر أو انتظر '
        'تجميع المزيد من القراءات.',
        style: pw.TextStyle(
          color: PdfColor.fromInt(0xFF92400E),
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

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
