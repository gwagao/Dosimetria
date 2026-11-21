# Dosímetro de sonido (Flutter + Python)

- `lib/` – app Android en Flutter: mide con el micrófono, calcula dosis %, TWA, Leq, Lmax/Lmin, gráfico en vivo, calibración manual y exportación a CSV. Normas NIOSH (85 dB, q=3) y OSHA (90 dB, q=5).
- `python/analyze.py` – analiza offline el CSV exportado (mismas fórmulas).

## Puesta en marcha

1. Instala Flutter y Android Studio (SDK de Android): https://docs.flutter.dev/get-started/install/windows/mobile
2. En esta carpeta, genera el andamiaje de Android sin tocar `lib/` ni `pubspec.yaml`:
   ```
   flutter create --platforms=android --project-name dosimetro .
   flutter pub get
   ```
3. Añade el permiso de micrófono en `android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>` y antes de `<application>`:
   ```xml
   <uses-permission android:name="android.permission.RECORD_AUDIO"/>
   ```
4. Conecta el móvil (depuración USB) y ejecuta `flutter run`. APK: `flutter build apk --release`.

## Análisis en Python

```
python python/analyze.py medicion.csv --std niosh --plot
```
(`--plot` requiere `pip install matplotlib`.)

## Limitaciones

El micrófono del móvil no está calibrado ni ponderado en A. Ajusta el deslizador de calibración comparando con un sonómetro de referencia. Las mediciones son orientativas y no sirven para cumplimiento legal.
