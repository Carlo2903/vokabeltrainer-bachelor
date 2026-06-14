import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';
import '../models/badge_model.dart';
import 'auth_provider.dart';

class GamificationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final AuthProvider _authProvider;

  UserProfile? _userProfile;
  List<BadgeModel> _badges = [];
  StreamSubscription<List<BadgeModel>>? _badgesSubscription;

  bool _isLoading = true;

  // Level-Up Event Stream
  final _levelUpController = StreamController<int>.broadcast();
  Stream<int> get onLevelUp => _levelUpController.stream;

  GamificationProvider(this._firestoreService, this._authProvider) {
    _authProvider.addListener(_onAuthStateChanged);
    _init();
  }

  UserProfile? get userProfile => _userProfile;
  List<BadgeModel> get badges => _badges;
  
  List<BadgeModel> get allBadges {
    return BadgeModel.catalog.map((catalogBadge) {
      try {
        return _badges.firstWhere((b) => b.id == catalogBadge.id);
      } catch (_) {
        try {
          return _badges.firstWhere((b) => b.name == catalogBadge.name);
        } catch (_) {
          return catalogBadge;
        }
      }
    }).toList();
  }

  bool get isLoading => _isLoading;

  int get currentXP => _userProfile?.xp ?? 0;
  int get currentLevel => _userProfile?.level ?? 1;
  int get currentStreak => _userProfile?.currentStreak ?? 0;

  int get xpForNextLevel => getXpRequiredForLevel(currentLevel + 1);

  void _onAuthStateChanged() {
    _init();
  }

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

    // Initialise empty profile if not found
    if (_userProfile == null) {
        _userProfile = UserProfile(
            uid: uid, 
            email: _authProvider.currentUser?.email ?? '', 
            displayName: _authProvider.currentUser?.displayName ?? 'User'
        );
        await _firestoreService.saveUserProfile(uid, _userProfile!.toFirestore());
    }

    _badgesSubscription?.cancel();
    _badgesSubscription = _firestoreService.watchBadges(uid).listen((badgesList) {
      _badges = badgesList;
      notifyListeners();
    });

    _isLoading = false;
    notifyListeners();
  }

  // --- XP & Level Logic ---

  int getXpRequiredForLevel(int level) {
    if (level <= 1) return 0;
    // Example curve: 
    // Level 2: 500
    // Level 3: 1200
    // After that: Adds exponentially or semi-linearly
    if (level == 2) return 500;
    if (level == 3) return 1200;
    
    // Formula for level > 3: previous_level_xp + (level * 400)
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

    // Check for level up
    while (newXp >= getXpRequiredForLevel(newLevel + 1)) {
      newLevel++;
    }

    bool leveledUp = newLevel > currentLevel;

    _userProfile = _userProfile!.copyWith(
      xp: newXp,
      level: newLevel,
    );

    notifyListeners();

    // Persist to Firestore
    await _firestoreService.saveUserProfile(_userProfile!.uid, {
      'xp': newXp,
      'level': newLevel,
    });

    if (leveledUp) {
      _levelUpController.add(newLevel);
      _checkLevelBadges(newLevel);
    }
  }

  // --- Streak Logic ---
  Future<void> updateStreakOnSessionComplete() async {
    if (_userProfile == null) return;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    int newStreak = currentStreak;
    DateTime? lastStudy = _userProfile?.lastStudyDate;

    if (lastStudy != null) {
      final lastStudyDay = DateTime(lastStudy.year, lastStudy.month, lastStudy.day);
      final difference = today.difference(lastStudyDay).inDays;

      if (difference == 1) {
        // Studied yesterday -> streak increments
        newStreak += 1;
      } else if (difference > 1) {
        // Missed a day -> streak resets to 1 (they studied today)
        newStreak = 1;
      }
      // If difference == 0, they already studied today. Streak remains the same.
    } else {
      // First time studying
      newStreak = 1;
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

  // --- Badge checking ---
  
  void _checkLevelBadges(int level) {
    if (level >= 10 && !_hasBadge('level_10')) {
      try {
        final badge = BadgeModel.catalog.firstWhere((b) => b.id == 'level_10').copyWith(unlockedAt: DateTime.now());
        _unlockBadge(badge);
      } catch (_) {}
    }
  }

  void _checkStreakBadges(int streak) {
    if (streak >= 7 && !_hasBadge('streak_7')) {
      try {
        final badge = BadgeModel.catalog.firstWhere((b) => b.id == 'streak_7').copyWith(unlockedAt: DateTime.now());
        _unlockBadge(badge);
      } catch (_) {}
    }
  }

  bool _hasBadge(String id) {
    return _badges.any((b) => b.id == id);
  }

  Future<void> _unlockBadge(BadgeModel badge) async {
    if (_userProfile == null) return;
    await _firestoreService.unlockBadge(_userProfile!.uid, badge);
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthStateChanged);
    _badgesSubscription?.cancel();
    _levelUpController.close();
    super.dispose();
  }
}
