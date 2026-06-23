import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/badge_model.dart';
import '../models/league_model.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

/// Verwaltet den gesamten Gamification-State: XP, Level, Streak, Badges, Liga.
///
/// Architektur-Prinzip: Alle Gamification-Aktionen laufen durch diesen Provider.
/// Er ist der einzige Ort, der weiß wie XP-Kurven, Badge-Bedingungen und Streak-Logik
/// funktionieren. Andere Provider (z.B. SessionProvider) rufen nur [sessionCompleted]
/// auf und müssen nicht wissen, was dahinter passiert — das ist das Facade-Pattern.
class GamificationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final AuthProvider _authProvider;

  UserProfile? _userProfile;
  List<BadgeModel> _badges = [];
  StreamSubscription<List<BadgeModel>>? _badgesSubscription;

  bool _isLoading = true;

  // XP die in der letzten Session verdient wurden (für LevelUpScreen)
  int _lastEarnedXp = 0;
  int get lastEarnedXp => _lastEarnedXp;

  // Level-Up Event Stream — UI kann darauf lauschen für Animations-Trigger
  final _levelUpController = StreamController<int>.broadcast();
  Stream<int> get onLevelUp => _levelUpController.stream;

  // Badge-Unlock Event Stream — UI kann Toast/Dialog zeigen
  final _badgeUnlockController = StreamController<BadgeModel>.broadcast();
  Stream<BadgeModel> get onBadgeUnlocked => _badgeUnlockController.stream;

  GamificationProvider(this._firestoreService, this._authProvider) {
    _authProvider.addListener(_onAuthStateChanged);
    _init();
  }

  // ── Getter ─────────────────────────────────────────────────────────────────

  UserProfile? get userProfile => _userProfile;
  List<BadgeModel> get badges => _badges;
  bool get isLoading => _isLoading;

  int get currentXP => _userProfile?.xp ?? 0;
  int get currentLevel => _userProfile?.level ?? 1;
  int get currentStreak => _userProfile?.currentStreak ?? 0;
  int get xpForNextLevel => getXpRequiredForLevel(currentLevel + 1);

  /// Aktuelle Liga berechnet aus XP — wird nicht in Firestore gespeichert.
  LeagueModel get currentLeague => LeagueModel.fromXp(currentXP);

  /// Kombinierter Badge-View: unlocked Badges mit Datum + gesperrte Badges aus Katalog.
  ///
  /// Das ist der "allBadges"-View für die UI: immer alle 8 Badges zeigen,
  /// manche gesperrt (grau), manche freigeschaltet (farbig mit Datum).
  List<BadgeModel> get allBadges {
    return BadgeModel.catalog.map((catalogBadge) {
      try {
        return _badges.firstWhere((b) => b.id == catalogBadge.id);
      } catch (_) {
        try {
          return _badges.firstWhere((b) => b.name == catalogBadge.name);
        } catch (_) {
          return catalogBadge; // nicht freigeschaltet
        }
      }
    }).toList();
  }

  // ── Init ───────────────────────────────────────────────────────────────────

  void _onAuthStateChanged() => _init();

  Future<void> _init() async {
    final uid = _authProvider.currentUser?.uid;
    if (uid == null) {
      _userProfile = null;
      _badges = [];
      _isLoading = false;
      _badgesSubscription?.cancel();
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _userProfile = await _firestoreService.getUserProfileModel(uid);

    // Neues Profil anlegen wenn noch nicht vorhanden
    if (_userProfile == null) {
      _userProfile = UserProfile(
        uid: uid,
        email: _authProvider.currentUser?.email ?? '',
        displayName: _authProvider.currentUser?.displayName ?? 'User',
      );
      await _firestoreService.saveUserProfile(uid, _userProfile!.toFirestore());
    }

    // Badge-Stream aus Firestore abonnieren
    _badgesSubscription?.cancel();
    _badgesSubscription = _firestoreService.watchBadges(uid).listen((list) {
      _badges = list;
      notifyListeners();
    });

    _isLoading = false;
    notifyListeners();
  }

  // ── Facade: Session abschließen ────────────────────────────────────────────

  /// Wird nach dem Abschluss einer Trainingseinheit aufgerufen.
  ///
  /// Kapselt alle Gamification-Aktionen einer Session:
  /// - XP hinzufügen
  /// - Streak aktualisieren
  /// - Badge-Bedingungen prüfen (Wörter, Sessions, Ligen, Sprachen)
  ///
  /// [correctCount] : Anzahl richtig beantworteter Wörter in dieser Session
  /// [masteredTotal]: Gesamtzahl aller gemeinerten Wörter (für Badge-Check)
  /// [languageCount]: Anzahl verschiedener Sprachen die der Nutzer lernt
  /// [sessionCount]  : Gesamtzahl abgeschlossener Sessions (inkl. dieser)
  Future<void> sessionCompleted({
    required int correctCount,
    required int masteredTotal,
    required int languageCount,
    required int sessionCount,
  }) async {
    if (_userProfile == null) return;

    // XP pro richtige Antwort = 10, Mindest-XP pro Session = 5
    final earned = (correctCount * 10).clamp(5, 500);
    _lastEarnedXp = earned;

    await addXP(earned);
    await updateStreakOnSessionComplete();

    // Badge-Checks für alle erlernbaren Badges
    _checkVocabBadges(masteredTotal);
    _checkSessionBadges(sessionCount);
    _checkLanguageBadges(languageCount);
  }

  // ── XP & Level ─────────────────────────────────────────────────────────────

  /// Erfahrungspunkte-Kurve. Beim Kolloquium erklärbar als:
  /// "Wachsende Anforderungen — jedes Level braucht mehr XP als das vorherige."
  int getXpRequiredForLevel(int level) {
    if (level <= 1) return 0;
    if (level == 2) return 500;
    if (level == 3) return 1200;
    // Ab Level 4: vorheriges Level + (level * 400) — semi-lineares Wachstum
    int xp = 1200;
    for (int i = 4; i <= level; i++) {
      xp += (i * 400);
    }
    return xp;
  }

  Future<void> addXP(int amount) async {
    if (_userProfile == null) return;

    final newXp = currentXP + amount;
    int newLevel = currentLevel;

    // Mehrfaches Level-Up in einem Schritt möglich (bei viel XP)
    while (newXp >= getXpRequiredForLevel(newLevel + 1)) {
      newLevel++;
    }

    final leveledUp = newLevel > currentLevel;

    _userProfile = _userProfile!.copyWith(xp: newXp, level: newLevel);
    notifyListeners();

    await _firestoreService.saveUserProfile(
        _userProfile!.uid, {'xp': newXp, 'level': newLevel});

    if (leveledUp) {
      _levelUpController.add(newLevel);
      _checkLevelBadges(newLevel);
    }
  }

  // ── Streak ─────────────────────────────────────────────────────────────────

  Future<void> updateStreakOnSessionComplete() async {
    if (_userProfile == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int newStreak = currentStreak;
    final lastStudy = _userProfile?.lastStudyDate;

    if (lastStudy != null) {
      final lastDay =
          DateTime(lastStudy.year, lastStudy.month, lastStudy.day);
      final diff = today.difference(lastDay).inDays;

      if (diff == 1) {
        newStreak += 1; // Gestern gelernt → Streak erhöhen
      } else if (diff > 1) {
        newStreak = 1; // Lücke → Streak zurücksetzen
      }
      // diff == 0: Heute schon gelernt → Streak unverändert
    } else {
      newStreak = 1; // Erstes Mal
    }

    _userProfile = _userProfile!.copyWith(
      currentStreak: newStreak,
      lastStudyDate: now,
    );
    notifyListeners();

    await _firestoreService.saveUserProfile(_userProfile!.uid, {
      'currentStreak': newStreak,
      'lastStudyDate': Timestamp.fromDate(now),
    });

    _checkStreakBadges(newStreak);
  }

  // ── Badge-Checks ───────────────────────────────────────────────────────────

  /// Level-basierte Badges: "Vokabel-Meister" bei Level 10.
  void _checkLevelBadges(int level) {
    if (level >= 10 && !_hasBadge('level_10')) {
      _triggerBadge('level_10');
    }
  }

  /// Streak-basierte Badges: "7 Tage Serie" bei 7 Tagen.
  void _checkStreakBadges(int streak) {
    if (streak >= 7 && !_hasBadge('streak_7')) {
      _triggerBadge('streak_7');
    }
  }

  /// Wortanzahl-Badges: "Eifriger Leser" (100 Wörter) + "Lexikon-Experte" (500).
  ///
  /// [masteredTotal] kommt aus VocabularyProvider.mastered.length
  void _checkVocabBadges(int masteredTotal) {
    if (masteredTotal >= 100 && !_hasBadge('reader')) {
      _triggerBadge('reader');
    }
    if (masteredTotal >= 500 && !_hasBadge('expert')) {
      _triggerBadge('expert');
    }
  }

  /// Sessions-Badges: "Schneller Lerner" nach 5 abgeschlossenen Sessions.
  ///
  /// [sessionCount] muss vom Aufrufer mitgezählt werden (in UserProfile oder SessionProvider).
  void _checkSessionBadges(int sessionCount) {
    if (sessionCount >= 5 && !_hasBadge('speed_learner')) {
      _triggerBadge('speed_learner');
    }
  }

  /// Sprachvielfalts-Badge: "Etymologie-König" bei 3+ verschiedenen Sprachen.
  ///
  /// [languageCount] kommt aus LanguageProvider.pairs.length
  void _checkLanguageBadges(int languageCount) {
    if (languageCount >= 3 && !_hasBadge('etymology')) {
      _triggerBadge('etymology');
    }
  }

  // ── Hilfsmethoden ──────────────────────────────────────────────────────────

  bool _hasBadge(String id) => _badges.any((b) => b.id == id);

  /// Sucht einen Badge aus dem Katalog, fügt `unlockedAt` hinzu und speichert ihn.
  void _triggerBadge(String id) {
    try {
      final badge = BadgeModel.catalog
          .firstWhere((b) => b.id == id)
          .copyWith(unlockedAt: DateTime.now());
      _unlockBadge(badge);
      // UI-Event emittieren (z.B. für Toast-Anzeige)
      _badgeUnlockController.add(badge);
    } catch (_) {
      // Badge-ID nicht im Katalog → ignorieren
    }
  }

  Future<void> _unlockBadge(BadgeModel badge) async {
    if (_userProfile == null) return;
    await _firestoreService.unlockBadge(_userProfile!.uid, badge);
  }

  // ── Öffentlich für direkte Aufrufe (z.B. aus SessionProvider) ─────────────

  /// Direkt zugängliche Methode für externe Checks (z.B. nach Vocab-Import).
  Future<void> checkAllBadges({
    required int masteredTotal,
    required int languageCount,
    required int sessionCount,
  }) async {
    _checkVocabBadges(masteredTotal);
    _checkLanguageBadges(languageCount);
    _checkSessionBadges(sessionCount);
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthStateChanged);
    _badgesSubscription?.cancel();
    _levelUpController.close();
    _badgeUnlockController.close();
    super.dispose();
  }
}
