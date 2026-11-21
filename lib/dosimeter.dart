import 'dart:math';

/// Norma de exposición: nivel criterio, tasa de intercambio y umbral.
class NoiseStandard {
  final String name;
  final double criterionDb; // nivel que da 100 % en [referenceHours]
  final double exchangeDb; // q: dB que halvan el tiempo permitido
  final double thresholdDb; // por debajo no se acumula dosis
  final double referenceHours;

  const NoiseStandard(
    this.name,
    this.criterionDb,
    this.exchangeDb,
    this.thresholdDb, {
    this.referenceHours = 8,
  });

  static const niosh = NoiseStandard('NIOSH (85 dB, q=3)', 85, 3, 0);
  static const osha = NoiseStandard('OSHA (90 dB, q=5)', 90, 5, 80);
  static const all = [niosh, osha];
}

class Sample {
  final DateTime time;
  final double db;
  Sample(this.time, this.db);
}

/// Acumula muestras de nivel sonoro y calcula dosis, TWA, Leq y Lmax.
class Dosimeter {
  NoiseStandard standard;
  final List<Sample> samples = [];

  double _doseFraction = 0; // 1.0 = 100 %
  double _energySum = 0; // sum(10^(L/10) * dt)
  double _elapsed = 0; // segundos
  double lmax = 0;
  double lmin = double.infinity;

  Dosimeter(this.standard);

  void reset() {
    samples.clear();
    _doseFraction = 0;
    _energySum = 0;
    _elapsed = 0;
    lmax = 0;
    lmin = double.infinity;
  }

  /// Añade una muestra; [dt] son los segundos que representa.
  void add(DateTime time, double db, double dt) {
    samples.add(Sample(time, db));
    _elapsed += dt;
    _energySum += pow(10, db / 10) * dt;
    if (db > lmax) lmax = db;
    if (db < lmin) lmin = db;
    if (db >= standard.thresholdDb) {
      final allowedSeconds = standard.referenceHours *
          3600 /
          pow(2, (db - standard.criterionDb) / standard.exchangeDb);
      _doseFraction += dt / allowedSeconds;
    }
  }

  double get dosePercent => _doseFraction * 100;

  double get leq => _elapsed == 0 ? 0 : 10 * log(_energySum / _elapsed) / ln10;

  /// Nivel medio ponderado a 8 h equivalente a la dosis actual.
  double get twa => _doseFraction <= 0
      ? 0
      : standard.criterionDb +
          standard.exchangeDb * log(_doseFraction) / log(2);

  /// Tiempo (s) hasta alcanzar 100 % si el nivel actual se mantiene.
  Duration? timeToFull(double currentDb) {
    if (currentDb < standard.thresholdDb) return null;
    final rate = 1 /
        (standard.referenceHours *
            3600 /
            pow(2, (currentDb - standard.criterionDb) / standard.exchangeDb));
    final remaining = 1 - _doseFraction;
    if (remaining <= 0) return Duration.zero;
    return Duration(seconds: (remaining / rate).round());
  }

  Duration get elapsed => Duration(seconds: _elapsed.round());

  String toCsv() {
    final b = StringBuffer('timestamp,db\n');
    for (final s in samples) {
      b.writeln('${s.time.toIso8601String()},${s.db.toStringAsFixed(1)}');
    }
    return b.toString();
  }
}
