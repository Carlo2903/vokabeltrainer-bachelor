import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vocabulary.dart';
import '../models/vocabulary_stack.dart';
import '../services/firestore_service.dart';

class VocabularyProvider extends ChangeNotifier {
  final FirestoreService _service;
  String? _uid;

  VocabularyProvider(this._service);

  List<Vocabulary> _vocabularies = [];
  StreamSubscription<List<Vocabulary>>? _subscription;
  String? _currentLanguagePairId;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<Vocabulary> get all => _vocabularies;

  List<Vocabulary> get masterBlock =>
      _vocabularies.where((v) => v.stack == VocabularyStack.masterBlock).toList();

  List<Vocabulary> get training =>
      _vocabularies.where((v) => v.stack == VocabularyStack.training).toList();

  List<Vocabulary> get review =>
      _vocabularies.where((v) => v.stack == VocabularyStack.review).toList();

  List<Vocabulary> get mastered =>
      _vocabularies.where((v) => v.stack == VocabularyStack.mastered).toList();

  int get totalWords => _vocabularies.length;

  double get masteryPercent =>
      totalWords == 0 ? 0 : mastered.length / totalWords;

  /// Wird vom main.dart aufgerufen wenn sich der User ändert
  void setUid(String? uid) {
    if (_uid == uid) return;
    _uid = uid;
    _subscription?.cancel();
    _vocabularies = [];
    _currentLanguagePairId = null;
    notifyListeners();
  }

  void subscribeToLanguagePair(String languagePairId) {
    if (_uid == null) return;
    if (_currentLanguagePairId == languagePairId) return;
    _currentLanguagePairId = languagePairId;
    _isLoading = true;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _service.watchVocabularies(_uid!, languagePairId).listen((list) {
      _vocabularies = list;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addVocabulary(Vocabulary vocab) async {
    if (_uid == null) return;
    await _service.addVocabulary(_uid!, vocab);
  }

  Future<void> importFromCatalog(String sourceLang, String targetLang, String pairId) async {
    if (_uid == null) return;
    
    // Bestimmen, welche Sprache aus dem Katalog geladen werden muss
    // Der Katalog enthält deutsche Begriffe ('term') und Übersetzungen in 'en' oder 'es' ('translation')
    String catalogLang = '';
    bool isReverse = false; // z.B. Englisch -> Deutsch
    
    if (sourceLang == 'Deutsch' && targetLang == 'Englisch') {
      catalogLang = 'en';
    } else if (sourceLang == 'Deutsch' && targetLang == 'Spanisch') {
      catalogLang = 'es';
    } else if (sourceLang == 'Englisch' && targetLang == 'Deutsch') {
      catalogLang = 'en';
      isReverse = true;
    } else if (sourceLang == 'Spanisch' && targetLang == 'Deutsch') {
      catalogLang = 'es';
      isReverse = true;
    } else if (sourceLang == 'Englisch' && targetLang == 'Spanisch') {
       // Für Englisch->Spanisch laden wir die englischen und spanischen Begriffe und matchen sie 
       // Das ist mit der aktuellen Datenstruktur komplex. Wir laden stattdessen die 'es' Einträge und tauschen term/translation wenn nötig
       // DA DIE DATENSTRUKTUR (term=Deutsch, translation=Fremdsprache) FIX IST:
       // Wir ignorieren Englisch<->Spanisch im automatischen Import erstmal oder bauen einen komplizierteren Matcher.
       // Einfachste Lösung: Import für diese Kombination überspringen.
       return;
    } else if (sourceLang == 'Spanisch' && targetLang == 'Englisch') {
       return;
    }

    if (catalogLang.isEmpty) return;

    final catalogItems = await _service.fetchGlobalCatalog(catalogLang);
    final batch = FirebaseFirestore.instance.batch();
    
    for (var item in catalogItems) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('vocabLists')
          .doc(pairId)
          .collection('vocabularies')
          .doc();

      final String term = isReverse ? item['translation'] : item['term'];
      final String translation = isReverse ? item['term'] : item['translation'];

      final vocab = Vocabulary(
        id: docRef.id,
        term: term,
        description: '', // Keine Description im Katalog
        translation: translation,
        stack: VocabularyStack.training,
        languagePairId: pairId,
        createdAt: DateTime.now(),
      );

      batch.set(docRef, vocab.toFirestore());
    }

    await batch.commit();
  }

  Future<void> moveToStack(String id, VocabularyStack stack) async {
    if (_uid == null || _currentLanguagePairId == null) return;
    await _service.moveToStack(_uid!, _currentLanguagePairId!, id, stack);
  }

  Future<void> deleteVocabulary(String id) async {
    if (_uid == null || _currentLanguagePairId == null) return;
    await _service.deleteVocabulary(_uid!, _currentLanguagePairId!, id);
  }

  Future<void> resetCourse(String pairId) async {
    if (_uid == null) return;
    await _service.resetLanguagePair(_uid!, pairId);
  }

  /// Gibt Vorschläge aus dem globalen Katalog zurück basierend auf Sprachpaar + Präfix.
  /// Gibt eine leere Liste zurück wenn das Paar nicht unterstützt wird.
  Future<List<({String term, String translation})>> searchSuggestions(
      String sourceLang, String targetLang, String query) async {
    final params = _catalogParams(sourceLang, targetLang);
    if (params == null || query.length < 2) return [];
    final raw = await _service.searchCatalogSuggestions(
      params.$1, query,
      isReverse: params.$2,
    );
    return raw.map((e) {
      final t = params.$2 ? (e['translation'] ?? '') : (e['term'] ?? '');
      final tr = params.$2 ? (e['term'] ?? '') : (e['translation'] ?? '');
      return (term: t as String, translation: tr as String);
    }).toList();
  }

  /// Sucht die Übersetzung eines Begriffs im globalen Katalog.
  /// Gibt null zurück wenn kein Eintrag gefunden wird oder das Paar nicht unterstützt wird.
  Future<String?> autoFillTranslation(
      String sourceLang, String targetLang, String term) async {
    final params = _catalogParams(sourceLang, targetLang);
    if (params == null) return null;
    return _service.findCatalogTranslation(params.$1, term, isReverse: params.$2);
  }

  /// Berechnet (catalogLang, isReverse) aus dem Sprachpaar.
  (String, bool)? _catalogParams(String source, String target) {
    if (source == 'Deutsch' && target == 'Englisch') return ('en', false);
    if (source == 'Deutsch' && target == 'Spanisch') return ('es', false);
    if (source == 'Englisch' && target == 'Deutsch') return ('en', true);
    if (source == 'Spanisch' && target == 'Deutsch') return ('es', true);
    return null; // EN↔ES nicht unterstützt
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
