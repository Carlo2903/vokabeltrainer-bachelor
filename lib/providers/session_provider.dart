import 'package:flutter/material.dart';
import '../models/vocabulary.dart';
import '../services/training_service.dart';
import 'gamification_provider.dart';
import 'vocabulary_provider.dart';
import 'language_provider.dart';

enum TranslationDirection { standard, reverse, mixed }

class SessionProvider extends ChangeNotifier {
  final TrainingService _trainingService;
  GamificationProvider? _gamificationProvider;
  VocabularyProvider? _vocabularyProvider;
  LanguageProvider? _languageProvider;

  // Zählt abgeschlossene Sessions (wird in Firestore NICHT gespeichert,
  // da es für die Bachelorarbeit nur als Badge-Trigger dient)
  int _totalSessionsCompleted = 0;

  SessionProvider(this._trainingService);

  void setGamificationProvider(GamificationProvider gamificationProvider) {
    _gamificationProvider = gamificationProvider;
  }

  /// Optional: Für Badge-Checks die Vocab- und Language-Provider setzen.
  void setContextProviders({
    VocabularyProvider? vocabProvider,
    LanguageProvider? languageProvider,
  }) {
    _vocabularyProvider = vocabProvider;
    _languageProvider = languageProvider;
  }

  List<Vocabulary> _queue = [];
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _isFinished = false;
  bool _isFlipped = false;
  TranslationDirection _direction = TranslationDirection.standard;
  int _sessionLength = 25;

  // ── Getters ──────────────────────────────────────────────────────────────

  bool get isFinished => _isFinished;
  bool get isFlipped => _isFlipped;
  bool get hasWords => _queue.isNotEmpty;
  int get currentIndex => _currentIndex;
  int get totalCount => _queue.length;
  int get correctCount => _correctCount;
  TranslationDirection get direction => _direction;
  int get sessionLength => _sessionLength;

  Vocabulary? get currentWord =>
      _queue.isNotEmpty && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;

  // Je nach Richtung: was wird vorne / hinten gezeigt
  String get frontText {
    final w = currentWord;
    if (w == null) return '';
    return _direction == TranslationDirection.reverse
        ? w.translation
        : w.term;
  }

  String get backText {
    final w = currentWord;
    if (w == null) return '';
    return _direction == TranslationDirection.reverse
        ? w.term
        : w.translation;
  }

  // ── Session Setup ─────────────────────────────────────────────────────────

  void setDirection(TranslationDirection dir) {
    _direction = dir;
    notifyListeners();
  }

  void setSessionLength(int length) {
    _sessionLength = length;
    notifyListeners();
  }

  void startSession(List<Vocabulary> allVocabs) {
    _queue = _trainingService.buildSession(allVocabs, _sessionLength);
    if (_direction == TranslationDirection.mixed) {
      // bei Mixed: Richtung per Wort zufällig
      _queue.shuffle();
    }
    _currentIndex = 0;
    _correctCount = 0;
    _isFinished = false;
    _isFlipped = false;
    notifyListeners();
  }

  void flipCard() {
    _isFlipped = !_isFlipped;
    notifyListeners();
  }

  // ── Bewertung ─────────────────────────────────────────────────────────────

  Future<void> markCorrect(String uid) async {
    final word = currentWord;
    if (word == null) return;
    await _trainingService.markCorrect(uid, word);
    _correctCount++;
    _advance();
  }

  Future<void> markWrong(String uid) async {
    final word = currentWord;
    if (word == null) return;
    await _trainingService.markWrong(uid, word);
    _advance();
  }

  void _advance() {
    _isFlipped = false;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else {
      _isFinished = true;
      _onSessionFinished();
    }
    notifyListeners();
  }

  /// Wird intern aufgerufen wenn die letzte Vokabel bewertet wurde.
  ///
  /// Ruft [GamificationProvider.sessionCompleted] auf — die Facade,
  /// die XP, Streak und alle Badge-Checks zusammen abwickelt.
  void _onSessionFinished() {
    _totalSessionsCompleted++;

    final masteredTotal = _vocabularyProvider?.mastered.length ?? 0;
    final languageCount = _languageProvider?.pairs.length ?? 0;

    _gamificationProvider?.sessionCompleted(
      correctCount: _correctCount,
      masteredTotal: masteredTotal,
      languageCount: languageCount,
      sessionCount: _totalSessionsCompleted,
    );
  }

  void resetSession() {
    _queue = [];
    _currentIndex = 0;
    _correctCount = 0;
    _isFinished = false;
    _isFlipped = false;
    notifyListeners();
  }
}
