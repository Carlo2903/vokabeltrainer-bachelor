/// Zentrale Konfiguration der App.
///
/// Die Backend-URL wird hier pro Umgebung definiert. Für den
/// Android-Emulator muss `10.0.2.2` verwendet werden (mapped auf
/// `localhost` des Host-Rechners). Für physische Geräte oder Flutter
/// Desktop direkt die lokale IP-Adresse eintragen.
class AppConfig {
  AppConfig._();

  // ── Backend ──────────────────────────────────────────────────────────

  /// Basis-URL des lokalen FastAPI-Backends.
  ///
  /// Android-Emulator : http://10.0.2.2:8000
  /// Physisches Gerät : http://[lokale-IP]:8000  (z. B. http://192.168.1.42:8000)
  /// Flutter Desktop  : http://localhost:8000
  static const String backendBaseUrl = 'http://10.0.2.2:8000';

  /// Timeout für normale API-Calls (Konjugation, Bewertung).
  static const Duration apiTimeout = Duration(seconds: 30);

  /// Timeout für Transkription – Whisper auf CPU kann länger dauern.
  static const Duration transcribeTimeout = Duration(seconds: 60);
}
