import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Liefert den aktuellen Auth-Zustand als Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Aktuell eingeloggter User (kann null sein)
  User? get currentUser => _auth.currentUser;

  // ── Email / Passwort ─────────────────────────────────────────────────────

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<UserCredential> registerWithEmail(
      String email, String password, String displayName) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Display-Name setzen
    await cred.user!.updateDisplayName(displayName.trim());
    // Userprofil in Firestore anlegen
    await _saveUserProfile(cred.user!.uid, displayName.trim(), email.trim(), null);
    return cred;
  }

  // ── Google Sign-In ───────────────────────────────────────────────────────

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // Abgebrochen

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);

    // Profil anlegen falls neuer User
    if (cred.additionalUserInfo?.isNewUser == true) {
      await _saveUserProfile(
        cred.user!.uid,
        cred.user!.displayName ?? 'User',
        cred.user!.email ?? '',
        cred.user!.photoURL,
      );
    }
    return cred;
  }

  // ── Profil-Update ────────────────────────────────────────────────────────

  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _db.collection('users').doc(uid).update({'displayName': name});
    }
  }

  Future<void> updatePhotoUrl(String url) async {
    await _auth.currentUser?.updatePhotoURL(url);
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _db.collection('users').doc(uid).update({'photoUrl': url});
    }
  }

  /// Ändert die E-Mail-Adresse. Erfordert Re-Authentifizierung mit currentPassword.
  Future<void> updateEmail(String newEmail, String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('Nicht eingeloggt');
    // Re-Authentifizierung
    final credential = EmailAuthProvider.credential(
        email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(credential);
    await user.verifyBeforeUpdateEmail(newEmail.trim());
    final uid = user.uid;
    // Firestore wird erst nach Verifizierung aktualisiert (Webhook)
    await _db.collection('users').doc(uid).update({'pendingEmail': newEmail.trim()});
  }

  /// Ändert das Passwort. Erfordert das aktuelle Passwort zur Re-Authentifizierung.
  Future<void> updatePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('Nicht eingeloggt');
    final credential = EmailAuthProvider.credential(
        email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Speichert das tägliche Lernziel (Anzahl Vokabeln) in Firestore.
  Future<void> saveDailyGoal(int goal) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _db.collection('users').doc(uid).update({'dailyGoal': goal});
    }
  }

  /// Gibt das tägliche Lernziel des Nutzers aus Firestore zurück.
  Future<int> getDailyGoal() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 20;
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['dailyGoal'] as int?) ?? 20;
  }

  // ── Abmelden ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Helper ───────────────────────────────────────────────────────────────

  Future<void> _saveUserProfile(
      String uid, String displayName, String email, String? photoUrl) async {
    await _db.collection('users').doc(uid).set({
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }
}
