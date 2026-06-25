import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../models/conjugation_result.dart';
import '../models/transcription_result.dart';

// ── Fehlerbehandlung ────────────────────────────────────────────────────────

/// Basisklasse für alle Backend-Fehler.
class BackendException implements Exception {
  final String message;
  const BackendException(this.message);

  @override
  String toString() => 'BackendException: $message';
}

/// Das Backend ist nicht erreichbar (Netzwerk, Server nicht gestartet).
class BackendUnreachableException extends BackendException {
  const BackendUnreachableException()
      : super('Backend nicht erreichbar. Ist der FastAPI-Server gestartet?');
}

/// Das Backend hat einen HTTP-Fehler zurückgegeben (4xx / 5xx).
class BackendHttpException extends BackendException {
  final int statusCode;
  BackendHttpException(this.statusCode, String message)
      : super('HTTP $statusCode: $message');
}

/// Das Backend hat eine ungültige JSON-Antwort geliefert.
class BackendParseException extends BackendException {
  const BackendParseException(super.message);
}

// ── Service ─────────────────────────────────────────────────────────────────

/// HTTP-Service für die Kommunikation mit dem lokalen FastAPI-Backend.
///
/// Kapselt alle drei KI-Endpunkte:
/// - [checkHealth]      → GET  /health
/// - [transcribeAudio]  → POST /api/transcribe
/// - [getConjugation]   → POST /api/chat  (mode=conjugation)
/// - [evaluateAnswer]   → POST /api/chat  (mode=evaluation)
///
/// Alle Methoden werfen [BackendException]-Subklassen bei Fehlern und
/// lassen normale Dart-Exceptions (z. B. [FormatException]) niemals
/// unkontrolliert nach oben durchdringen.
class BackendService {
  BackendService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Uri _base = Uri.parse(AppConfig.backendBaseUrl);

  // ── Health ─────────────────────────────────────────────────────────────

  /// Prüft ob das Backend erreichbar ist.
  ///
  /// Gibt [true] zurück wenn der Server antwortet, wirft
  /// [BackendUnreachableException] wenn er nicht erreichbar ist.
  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(_base.replace(path: '/health'))
          .timeout(AppConfig.apiTimeout);
      _assertSuccess(response);
      return true;
    } on BackendException {
      rethrow;
    } on SocketException {
      throw const BackendUnreachableException();
    } on Exception {
      throw const BackendUnreachableException();
    }
  }

  // ── Transkription ──────────────────────────────────────────────────────

  /// Schickt eine Audiodatei an Whisper und gibt den transkribierten Text zurück.
  ///
  /// [audioFile]  – Die aufgenommene Audiodatei (.m4a von der record-Library).
  /// [mimeType]   – MIME-Typ der Datei, Standard: audio/mp4 (für .m4a).
  ///
  /// Wirft [BackendException] bei Verbindungs- oder HTTP-Fehlern.
  Future<TranscriptionResult> transcribeAudio(
    File audioFile, {
    String mimeType = 'audio/mp4', // .m4a ist ein MPEG-4-Audiocontainer
  }) async {
    // Datei-Validierung vor dem Senden:
    // Eine nicht-existente oder leere Datei würde sofort 422 produzieren.
    if (!audioFile.existsSync()) {
      throw const BackendException('Audiodatei existiert nicht.');
    }
    final fileSize = audioFile.lengthSync();
    if (fileSize < 1024) {
      // Weniger als 1 KB → Aufnahme war zu kurz oder fehlgeschlagen
      throw BackendException(
        'Audiodatei zu klein ($fileSize Bytes). Bitte länger sprechen.',
      );
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        _base.replace(path: '/api/transcribe'),
      );

      request.files.add(await http.MultipartFile.fromPath(
        'audio', // Backend erwartet Feldname 'audio' (nicht 'file')
        audioFile.path,
        contentType: MediaType.parse(mimeType),
      ));

      final streamedResponse = await _client
          .send(request)
          .timeout(AppConfig.transcribeTimeout);

      final response = await http.Response.fromStream(streamedResponse);
      _assertSuccess(response);

      final json = _decodeJson(response.body);
      return TranscriptionResult.fromJson(json);
    } on BackendException {
      rethrow;
    } on SocketException {
      throw const BackendUnreachableException();
    } on Exception catch (e) {
      throw BackendException('Transkription fehlgeschlagen: $e');
    }
  }

  // ── Konjugation ────────────────────────────────────────────────────────

  /// Generiert eine Konjugationstabelle für ein Verb via Ollama.
  ///
  /// [verb]      – Verb in der Grundform, z. B. "aprender".
  /// [language]  – Sprache des Verbs, z. B. "Spanisch".
  ///
  /// Wirft [BackendException] bei Verbindungs- oder HTTP-Fehlern.
  Future<ConjugationResult> getConjugation(
    String verb,
    String language,
  ) async {
    try {
      final response = await _client
          .post(
            _base.replace(path: '/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mode': 'conjugation',
              'word': verb,        // Backend erwartet 'word', nicht 'verb'
              'language': language,
            }),
          )
          .timeout(AppConfig.apiTimeout);

      _assertSuccess(response);
      final json = _decodeJson(response.body);
      return ConjugationResult.fromJson(
        json,
        verb: verb,
        language: language,
      );
    } on BackendException {
      rethrow;
    } on SocketException {
      throw const BackendUnreachableException();
    } on Exception catch (e) {
      throw BackendException('Konjugationsabfrage fehlgeschlagen: $e');
    }
  }

  // ── Antwortbewertung ───────────────────────────────────────────────────

  /// Lässt das Sprachmodell bewerten ob [userAnswer] inhaltlich korrekt ist.
  ///
  /// [userAnswer]    – Die (transkribierte) Antwort des Nutzers.
  /// [correctAnswer] – Die erwartete korrekte Übersetzung/Antwort.
  /// [vocabulary]    – Optional: das Vokabelwort zur besseren Kontextualisierung.
  ///
  /// Gibt [true] zurück wenn das Modell die Antwort als korrekt bewertet.
  /// Wirft [BackendException] bei Verbindungs- oder HTTP-Fehlern.
  Future<bool> evaluateAnswer({
    required String userAnswer,
    required String correctAnswer,
    String? word,       // Das Vokabel-Wort (term) für Kontext
    String? language,  // Sprache für Kontext
  }) async {
    try {
      final response = await _client
          .post(
            _base.replace(path: '/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mode': 'evaluation',
              'word': word ?? '',           // Backend erwartet 'word'
              'language': language ?? '',   // Backend erwartet 'language'
              'user_answer': userAnswer,
              'correct_answer': correctAnswer,
            }),
          )
          .timeout(AppConfig.apiTimeout);

      _assertSuccess(response);
      final json = _decodeJson(response.body);

      // Backend liefert { "is_correct": true/false, "feedback": "..." }
      final correct = json['is_correct'];
      if (correct is bool) return correct;

      // Fallback: Textauswertung wenn Backend nur Textantwort liefert
      final responseText =
          (json['feedback'] as String? ?? json['response'] as String? ?? '').toLowerCase();
      return responseText.contains('correct') ||
          responseText.contains('richtig') ||
          responseText.contains('ja');
    } on BackendException {
      rethrow;
    } on SocketException {
      throw const BackendUnreachableException();
    } on Exception catch (e) {
      throw BackendException('Bewertung fehlgeschlagen: $e');
    }
  }

  // ── Private Hilfsmethoden ──────────────────────────────────────────────

  /// Wirft [BackendHttpException] wenn der Statuscode kein 2xx ist.
  void _assertSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = response.body;
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        detail = json['detail']?.toString() ?? detail;
      } catch (_) {}
      throw BackendHttpException(response.statusCode, detail);
    }
  }

  /// Dekodiert den JSON-Body sicher und wirft [BackendParseException] bei Fehler.
  Map<String, dynamic> _decodeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw BackendParseException('Ungültige JSON-Antwort: $e');
    }
  }

  /// Gibt den HTTP-Client frei. Sollte aufgerufen werden wenn der Service
  /// nicht mehr benötigt wird (z. B. in dispose()).
  void dispose() => _client.close();
}
