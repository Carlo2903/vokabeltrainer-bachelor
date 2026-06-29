import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/conjugation_result.dart';
import '../models/transcription_result.dart';
import '../services/backend_service.dart';

/// Status einer laufenden Backend-Operation.
enum BackendStatus {
  idle,
  loading,
  success,
  error,
}

/// Zentraler Provider für alle KI-Interaktionen mit dem FastAPI-Backend.
///
/// Screens subscriben via `context.watch<BackendProvider>()` und erhalten
/// automatisch Rebuilds wenn sich [status], [lastError] oder Ergebnisse ändern.
///
/// Registrierung in main.dart:
/// ```dart
/// Provider<BackendService>.value(value: BackendService()),
/// ChangeNotifierProvider(create: (ctx) => BackendProvider(ctx.read<BackendService>())),
/// ```
class BackendProvider extends ChangeNotifier {
  BackendProvider(this._service);

  final BackendService _service;

  // ── State ────────────────────────────────────────────────────────────

  BackendStatus _status = BackendStatus.idle;
  String? _lastError;
  bool? _backendReachable;

  TranscriptionResult? _lastTranscription;
  ConjugationResult? _lastConjugation;
  bool? _lastEvaluationResult;

  // ── Getters ───────────────────────────────────────────────────────────

  BackendStatus get status => _status;
  bool get isLoading => _status == BackendStatus.loading;
  bool get hasError => _status == BackendStatus.error;
  String? get lastError => _lastError;
  bool? get backendReachable => _backendReachable;

  TranscriptionResult? get lastTranscription => _lastTranscription;
  ConjugationResult? get lastConjugation => _lastConjugation;
  bool? get lastEvaluationResult => _lastEvaluationResult;

  // ── Health Check ──────────────────────────────────────────────────────

  /// Prüft die Erreichbarkeit des Backends und speichert das Ergebnis.
  Future<bool> checkHealth() async {
    _setLoading();
    try {
      final reachable = await _service.checkHealth();
      _backendReachable = reachable;
      _setIdle();
      return reachable;
    } on BackendException catch (e) {
      _backendReachable = false;
      _setError(e.message);
      return false;
    }
  }

  // ── Transkription ─────────────────────────────────────────────────────

  /// Transkribiert eine Audiodatei und speichert das Ergebnis in [lastTranscription].
  ///
  /// [language] – ISO-639-1 Code für Whisper (z.B. "de", "es"). Leer = auto.
  /// Gibt [TranscriptionResult] zurück oder null bei Fehler.
  Future<TranscriptionResult?> transcribeAudio(
    File audioFile, {
    String language = '',
  }) async {
    _setLoading();
    _lastTranscription = null;
    try {
      final result = await _service.transcribeAudio(
        audioFile,
        language: language,
      );
      _lastTranscription = result;
      _setSuccess();
      return result;
    } on BackendException catch (e) {
      _setError(e.message);
      return null;
    }
  }

  // ── Konjugation ───────────────────────────────────────────────────────

  /// Generiert eine Konjugationstabelle und speichert sie in [lastConjugation].
  ///
  /// Gibt [ConjugationResult] zurück oder null bei Fehler.
  Future<ConjugationResult?> getConjugation(
    String verb,
    String language,
  ) async {
    _setLoading();
    _lastConjugation = null;
    try {
      final result = await _service.getConjugation(verb, language);
      _lastConjugation = result;
      _setSuccess();
      return result;
    } on BackendException catch (e) {
      _setError(e.message);
      return null;
    }
  }

  // ── Antwortbewertung ──────────────────────────────────────────────────

  /// Bewertet eine Nutzerantwort und speichert das Ergebnis in [lastEvaluationResult].
  ///
  /// Gibt [true/false] zurück oder null bei Fehler.
  Future<bool?> evaluateAnswer({
    required String userAnswer,
    required String correctAnswer,
    String? word,
    String? language,
  }) async {
    _setLoading();
    _lastEvaluationResult = null;
    try {
      final result = await _service.evaluateAnswer(
        userAnswer: userAnswer,
        correctAnswer: correctAnswer,
        word: word,
        language: language,
      );
      _lastEvaluationResult = result;
      _setSuccess();
      return result;
    } on BackendException catch (e) {
      _setError(e.message);
      return null;
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────

  /// Setzt alle transienten Zustände zurück (z. B. beim Verlassen eines Screens).
  void reset() {
    _status = BackendStatus.idle;
    _lastError = null;
    _lastTranscription = null;
    _lastConjugation = null;
    _lastEvaluationResult = null;
    notifyListeners();
  }

  // ── Private Hilfsmethoden ─────────────────────────────────────────────

  void _setLoading() {
    _status = BackendStatus.loading;
    _lastError = null;
    notifyListeners();
  }

  void _setSuccess() {
    _status = BackendStatus.success;
    notifyListeners();
  }

  void _setIdle() {
    _status = BackendStatus.idle;
    notifyListeners();
  }

  void _setError(String message) {
    _status = BackendStatus.error;
    _lastError = message;
    notifyListeners();
  }
}
