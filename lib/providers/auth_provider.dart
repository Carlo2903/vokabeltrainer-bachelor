import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider(this._authService) {
    _init();
  }

  User? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<User?>? _subscription;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  String? get errorMessage => _errorMessage;

  void _init() {
    _subscription = _authService.authStateChanges.listen((user) async {
      _currentUser = user;
      _isLoading = false;

      if (user != null) {
        // Profilbild aus Firestore laden (Base64 steht dort, nicht in Firebase Auth)
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final firestorePhotoUrl = doc.data()?['photoUrl'] as String?;
          if (firestorePhotoUrl != null && firestorePhotoUrl.isNotEmpty) {
            _photoUrlOverride = firestorePhotoUrl;
          }
        } catch (_) {
          // Kein Netzwerk o.ä. – weiter mit Firebase Auth photoURL
        }
      } else {
        // Ausgeloggt → Override zurücksetzen
        _photoUrlOverride = null;
      }

      notifyListeners();
    });
  }

  // ── Email/Passwort ───────────────────────────────────────────────────────

  Future<bool> signIn(String email, String password) async {
    _setError(null);
    try {
      await _authService.signInWithEmail(email, password);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapAuthError(e.code));
      return false;
    }
  }

  Future<bool> register(String email, String password, String displayName) async {
    _setError(null);
    try {
      await _authService.registerWithEmail(email, password, displayName);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapAuthError(e.code));
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _setError(null);
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapAuthError(e.code));
      return false;
    } catch (_) {
      _setError('Fehler beim Senden der E-Mail.');
      return false;
    }
  }

  // ── Google ───────────────────────────────────────────────────────────────

  Future<bool> signInWithGoogle() async {
    _setError(null);
    try {
      final cred = await _authService.signInWithGoogle();
      return cred != null;
    } on FirebaseAuthException catch (e) {
      _setError(_mapAuthError(e.code));
      return false;
    } catch (_) {
      _setError('Google-Login fehlgeschlagen.');
      return false;
    }
  }

  // ── Abmelden ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _authService.signOut();
  }

  // ── Profilbild ───────────────────────────────────────────────────────────

  Future<void> updatePhotoUrl(String url) async {
    await _authService.updatePhotoUrl(url);
    await _authService.currentUser?.reload();
    _currentUser = _authService.currentUser;
    notifyListeners();
  }

  /// Für Base64-Profilbilder
  void updatePhotoUrlLocalOnly(String dataUri) {
    _photoUrlOverride = dataUri;
    notifyListeners();
  }

  String? _photoUrlOverride;

  /// Gibt die photoURL zurück – priorisiert den lokalen Override (Base64)
  String? get photoUrl => _photoUrlOverride ?? _currentUser?.photoURL;

  /// Ändert die E-Mail mit Re-Authentifizierung.
  Future<void> changeEmail(String newEmail, String currentPassword) async {
    try {
      await _authService.updateEmail(newEmail, currentPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e.code));
    }
  }

  /// Ändert das Passwort mit Re-Authentifizierung.
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      await _authService.updatePassword(currentPassword, newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e.code));
    }
  }

  /// Tägliches Lernziel speichern / lesen
  Future<void> saveDailyGoal(int goal) => _authService.saveDailyGoal(goal);
  Future<int> getDailyGoal() => _authService.getDailyGoal();

  // ── Helper ───────────────────────────────────────────────────────────────

  void _setError(String? msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'invalid-credential':
        return 'E-Mail oder Passwort ist falsch (oder noch nicht registriert).';
      case 'user-not-found':
        return 'Kein Account mit dieser E-Mail gefunden.';
      case 'wrong-password':
        return 'Falsches Passwort.';
      case 'email-already-in-use':
        return 'Diese E-Mail-Adresse wird bereits verwendet.';
      case 'invalid-email':
        return 'Ungültige E-Mail-Adresse.';
      case 'weak-password':
        return 'Das Passwort muss mindestens 6 Zeichen lang sein.';
      case 'network-request-failed':
        return 'Keine Internetverbindung.';
      default:
        return 'Fehler: $code';
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
