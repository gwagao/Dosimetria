import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'dosimeter.dart';

/// Genera el informe PDF de una medición.
Future<Uint8List> buildReport(Dosimeter d, {required double calibration}) async {
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(await rootBundle.load('assets/fonts/roboto-regular.ttf')),
    bold: pw.Font.ttf(await rootBundle.load('assets/fonts/roboto-bold.ttf')),
  );
  final doc = pw.Document(theme: theme);
  final start = d.samples.first.time;
  final end = d.samples.last.time;
  final dose = d.dosePercent;
  final s = d.standard;

  String two(int n) => n.toString().padLeft(2, '0');
  String dt(DateTime t) =>
      '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  String dur(Duration x) =>
      '${two(x.inHours)}:${two(x.inMinutes % 60)}:${two(x.inSeconds % 60)}';

  final verdict = dose >= 100
      ? 'LÍMITE SUPERADO: la dosis alcanza o supera el 100 % del máximo permitido.'
      : dose >= 50
          ? 'ATENCIÓN: la dosis supera el 50 % (nivel de acción habitual).'
          : 'La dosis está por debajo del 50 % del máximo permitido.';

  // Reduce a ~200 puntos para el gráfico.
  final step = (d.samples.length / 200).ceil().clamp(1, 1 << 30);
  final pts = <pw.PointChartValue>[];
  for (var i = 0; i < d.samples.length; i += step) {
    pts.add(pw.PointChartValue(
        d.samples[i].time.difference(start).inSeconds.toDouble(),
        d.samples[i].db.clamp(30, 120).toDouble()));
  }
  final maxX = pts.last.x <= 0 ? 1.0 : pts.last.x;

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    build: (ctx) => [
      pw.Text('Informe de dosimetría de ruido',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text('Generado: ${dt(DateTime.now())}'),
      pw.SizedBox(height: 14),
      pw.TableHelper.fromTextArray(
        cellAlignment: pw.Alignment.centerLeft,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headers: ['Parámetro', 'Valor'],
        data: [
          ['Norma', s.name],
          ['Inicio', dt(start)],
          ['Fin', dt(end)],
          ['Duración', dur(d.elapsed)],
          ['Dosis', '${dose.toStringAsFixed(2)} %'],
          ['TWA (8 h)', '${d.twa.toStringAsFixed(1)} dB'],
          ['Leq', '${d.leq.toStringAsFixed(1)} dB'],
          ['Lmax', '${d.lmax.toStringAsFixed(1)} dB'],
          ['Lmin', '${d.lmin.toStringAsFixed(1)} dB'],
          ['Calibración aplicada',
              '${calibration >= 0 ? '+' : ''}${calibration.toStringAsFixed(1)} dB'],
          ['Muestras', '${d.samples.length}'],
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Text(verdict, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 14),
      pw.Text('Nivel sonoro en el tiempo',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.SizedBox(
        height: 220,
        child: pw.Chart(
          grid: pw.CartesianGrid(
            xAxis: pw.FixedAxis(
              [0, maxX / 2, maxX],
              format: (v) => dur(Duration(seconds: v.round())),
            ),
            yAxis: pw.FixedAxis([30, 50, 70, 90, 110],
                format: (v) => '$v dB'),
          ),
          datasets: [
            pw.LineDataSet(
              data: pts,
              drawPoints: false,
              isCurved: false,
              color: PdfColors.teal,
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 16),
      pw.Text(
        'Medición obtenida con el micrófono de un teléfono móvil, sin ponderación A '
        'ni calibración certificada. Los valores son orientativos y no sirven para '
        'cumplimiento legal.',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    ],
  ));
  return doc.save();
}
