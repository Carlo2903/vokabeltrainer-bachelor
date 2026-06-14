import 'dart:async';
import 'package:flutter/material.dart';
import '../models/language_pair.dart';
import '../services/firestore_service.dart';

class LanguageProvider extends ChangeNotifier {
  final FirestoreService _service;
  String? _uid;

  LanguageProvider(this._service);

  List<LanguagePair> _pairs = [];
  LanguagePair? _selected;
  StreamSubscription<List<LanguagePair>>? _subscription;
  bool _isLoading = true;

  bool get isLoading => _isLoading;
  List<LanguagePair> get pairs => _pairs;
  LanguagePair? get selected => _selected;

  /// Wird vom main.dart aufgerufen wenn sich der User ändert
  void setUid(String? uid) {
    if (_uid == uid) return;
    _uid = uid;
    _subscription?.cancel();
    _pairs = [];
    _selected = null;
    if (uid != null) {
      _isLoading = true;
      _subscribe(uid);
    } else {
      _isLoading = false;
    }
    notifyListeners();
  }

  void _subscribe(String uid) {
    _subscription = _service.watchLanguagePairs(uid).listen((list) {
      _pairs = list;
      _isLoading = false;
      if (_selected == null && list.isNotEmpty) {
        _selected = list.first;
      }
      notifyListeners();
    });
  }

  void selectPair(LanguagePair pair) {
    _selected = pair;
    notifyListeners();
  }

  Future<LanguagePair> addLanguagePair(LanguagePair pair) async {
    if (_uid == null) throw Exception('User not logged in');
    final id = await _service.addLanguagePair(_uid!, pair);
    final created = LanguagePair(
      id: id,
      title: pair.title,
      sourceLanguage: pair.sourceLanguage,
      sourceFlag: pair.sourceFlag,
      targetLanguage: pair.targetLanguage,
      targetFlag: pair.targetFlag,
      level: pair.level,
      createdAt: pair.createdAt,
    );
    _selected = created;
    notifyListeners();
    return created;
  }

  Future<void> deleteLanguagePair(String pairId) async {
    if (_uid == null) return;
    await _service.deleteLanguagePair(_uid!, pairId);
    if (_selected?.id == pairId) {
      _selected = _pairs.where((p) => p.id != pairId).firstOrNull;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
