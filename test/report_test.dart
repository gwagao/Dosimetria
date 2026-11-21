import 'dart:io';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_test/flutter_test.dart';
import 'package:dosimetro/dosimeter.dart';
import 'package:dosimetro/report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('genera un PDF válido', () async {
    final d = Dosimeter(NoiseStandard.niosh);
    final t0 = DateTime(2026, 1, 1, 8);
    for (var i = 0; i < 600; i++) {
      d.add(t0.add(Duration(seconds: i)), 80 + (i % 20).toDouble(), 1);
    }
    final bytes = await buildReport(d, calibration: 2.5);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    File('${Directory.systemTemp.path}/informe_test.pdf').writeAsBytesSync(bytes);
    expect(d.dosePercent, greaterThan(0));
  });
}
