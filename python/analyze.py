"""Analiza un CSV exportado por la app Dosímetro (timestamp,db).

Uso:
    python analyze.py medicion.csv [--std niosh|osha] [--plot]
"""
import argparse
import csv
import math
from datetime import datetime

STANDARDS = {
    "niosh": {"criterion": 85.0, "exchange": 3.0, "threshold": 0.0},
    "osha": {"criterion": 90.0, "exchange": 5.0, "threshold": 80.0},
}
REF_SECONDS = 8 * 3600


def load(path):
    times, levels = [], []
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            times.append(datetime.fromisoformat(row["timestamp"]))
            levels.append(float(row["db"]))
    return times, levels


def analyze(times, levels, std):
    dose = energy = total = 0.0
    for i in range(1, len(levels)):
        dt = (times[i] - times[i - 1]).total_seconds()
        db = levels[i]
        total += dt
        energy += 10 ** (db / 10) * dt
        if db >= std["threshold"]:
            allowed = REF_SECONDS / 2 ** ((db - std["criterion"]) / std["exchange"])
            dose += dt / allowed
    leq = 10 * math.log10(energy / total) if total else 0.0
    twa = std["criterion"] + std["exchange"] * math.log2(dose) if dose > 0 else 0.0
    return {
        "duracion_s": total,
        "dosis_%": dose * 100,
        "TWA_dB": twa,
        "Leq_dB": leq,
        "Lmax_dB": max(levels),
        "Lmin_dB": min(levels),
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("csv")
    p.add_argument("--std", choices=STANDARDS, default="niosh")
    p.add_argument("--plot", action="store_true", help="requiere matplotlib")
    args = p.parse_args()

    times, levels = load(args.csv)
    if len(levels) < 2:
        raise SystemExit("El CSV necesita al menos 2 muestras")
    for k, v in analyze(times, levels, STANDARDS[args.std]).items():
        print(f"{k:12s} {v:10.2f}")

    if args.plot:
        import matplotlib.pyplot as plt

        plt.plot(times, levels)
        plt.ylabel("dB")
        plt.title(f"Medición ({args.std.upper()})")
        plt.grid(alpha=0.3)
        plt.show()


if __name__ == "__main__":
    main()
