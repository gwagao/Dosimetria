import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'dosimeter.dart';
import 'report.dart';

void main() => runApp(const DosimetroApp());

class DosimetroApp extends StatelessWidget {
  const DosimetroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dosímetro',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const DosimeterPage(),
    );
  }
}

class DosimeterPage extends StatefulWidget {
  const DosimeterPage({super.key});

  @override
  State<DosimeterPage> createState() => _DosimeterPageState();
}

class _DosimeterPageState extends State<DosimeterPage> {
  final _dosimeter = Dosimeter(NoiseStandard.niosh);
  NoiseMeter? _meter;
  StreamSubscription<NoiseReading>? _sub;
  DateTime? _lastTime;
  double _current = 0;
  double _calibration = 0; // dB de ajuste frente a un sonómetro de referencia
  bool _running = false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _snack('Se necesita permiso de micrófono');
      return;
    }
    _meter ??= NoiseMeter();
    _lastTime = null;
    _sub = _meter!.noise.listen(_onReading, onError: (e) {
      _snack('Error de micrófono: $e');
      _stop();
    });
    setState(() => _running = true);
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    setState(() => _running = false);
  }

  void _onReading(NoiseReading r) {
    final now = DateTime.now();
    final dt = _lastTime == null
        ? 0.0
        : now.difference(_lastTime!).inMilliseconds / 1000.0;
    _lastTime = now;
    final db = r.meanDecibel + _calibration;
    if (!db.isFinite) return;
    setState(() {
      _current = db;
      if (dt > 0) _dosimeter.add(now, db, dt);
    });
  }

  Future<void> _exportPdf() async {
    if (_dosimeter.samples.length < 2) {
      _snack('No hay datos suficientes para el informe');
      return;
    }
    final bytes = await buildReport(_dosimeter, calibration: _calibration);
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/informe_dosimetria_$stamp.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Informe de dosimetría');
  }

  Future<void> _exportCsv() async {
    if (_dosimeter.samples.isEmpty) {
      _snack('No hay datos que exportar');
      return;
    }
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/dosimetro_$stamp.csv');
    await file.writeAsString(_dosimeter.toCsv());
    await Share.shareXFiles([XFile(file.path)], text: 'Medición de dosimetría');
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  void _showInfo() => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Aviso'),
          content: const Text(
            'El micrófono del móvil no está calibrado ni ponderado en A. '
            'Ajusta la calibración contra un sonómetro de referencia. '
            'Los valores son orientativos, no válidos para cumplimiento legal.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))
          ],
        ),
      );

  Color _doseColor(double d) =>
      d < 50 ? Colors.greenAccent : (d < 100 ? Colors.orangeAccent : Colors.redAccent);

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final d = _dosimeter;
    final ttf = d.timeToFull(_current);
    final has = d.samples.isNotEmpty;
    String db(double v) => '${v.toStringAsFixed(1)} dB';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dosímetro de sonido'),
        toolbarHeight: 48,
        actions: [
          IconButton(
              onPressed: _showInfo, icon: const Icon(Icons.info_outline)),
        ],
      ),
      // Sin scroll: el gráfico (Expanded) absorbe el espacio sobrante.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(
            children: [
              FittedBox(
                child: Text(
                  db(_current),
                  style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
                ),
              ),
              LinearProgressIndicator(
                value: (d.dosePercent / 100).clamp(0.0, 1.0),
                minHeight: 10,
                color: _doseColor(d.dosePercent),
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 2),
              Text('Dosis: ${d.dosePercent.toStringAsFixed(2)} %',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _ChartPainter(
                        d.samples, Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                _Stat('TWA', d.dosePercent == 0 ? '--' : db(d.twa)),
                _Stat('Leq', has ? db(d.leq) : '--'),
                _Stat('Lmax', has ? db(d.lmax) : '--'),
              ]),
              Row(children: [
                _Stat('Lmin', has ? db(d.lmin) : '--'),
                _Stat('Tiempo', _fmt(d.elapsed)),
                _Stat('Al 100 %', ttf == null ? '--' : _fmt(ttf)),
              ]),
              DropdownButtonFormField<NoiseStandard>(
                initialValue: d.standard,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Norma', isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                items: [
                  for (final s in NoiseStandard.all)
                    DropdownMenuItem(value: s, child: Text(s.name)),
                ],
                // Cambiar de norma reinicia la medición para no mezclar criterios.
                onChanged: _running
                    ? null
                    : (s) => setState(() {
                          d.standard = s!;
                          d.reset();
                        }),
              ),
              Row(children: [
                SizedBox(
                  width: 88,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                        'Calib. ${_calibration >= 0 ? '+' : ''}${_calibration.toStringAsFixed(1)} dB',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _calibration,
                    min: -20,
                    max: 20,
                    divisions: 80,
                    onChanged: (v) => setState(() => _calibration = v),
                  ),
                ),
              ]),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _running ? _stop : _start,
                      icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                      label: Text(_running ? 'Detener' : 'Iniciar'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    onPressed: _running ? null : () => setState(d.reset),
                    icon: const Icon(Icons.restart_alt),
                    tooltip: 'Reiniciar',
                  ),
                  IconButton.filledTonal(
                    onPressed: _running ? null : _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    tooltip: 'Informe PDF',
                  ),
                  IconButton.filledTonal(
                    onPressed: _exportCsv,
                    icon: const Icon(Icons.table_chart),
                    tooltip: 'Exportar CSV',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              FittedBox(
                child: Text(value,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gráfico de las últimas muestras (30–120 dB).
class _ChartPainter extends CustomPainter {
  final List<Sample> samples;
  final Color color;
  _ChartPainter(this.samples, this.color);

  static const _maxPoints = 300;
  static const _minDb = 30.0, _maxDb = 120.0;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    for (var db = 40.0; db <= 110; db += 20) {
      final y = size.height * (1 - (db - _minDb) / (_maxDb - _minDb));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (samples.length < 2) return;
    final data = samples.length > _maxPoints
        ? samples.sublist(samples.length - _maxPoints)
        : samples;
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = size.width * i / (_maxPoints - 1);
      final y = size.height *
          (1 - ((data[i].db.clamp(_minDb, _maxDb)) - _minDb) / (_maxDb - _minDb));
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}
