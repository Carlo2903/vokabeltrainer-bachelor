import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vocabulary.dart';
import '../models/vocabulary_stack.dart';
import '../models/language_pair.dart';
import '../models/user_profile.dart';
import '../models/badge_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Basis-Pfade (user-scoped) ─────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _vocabLists(String uid) =>
      _db.collection('users').doc(uid).collection('vocabLists');

  CollectionReference<Map<String, dynamic>> _vocabularies(
          String uid, String languagePairId) =>
      _vocabLists(uid).doc(languagePairId).collection('vocabularies');

  // ── Vokabeln ──────────────────────────────────────────────────────────────

  Stream<List<Vocabulary>> watchVocabularies(String uid, String languagePairId) {
    return _vocabularies(uid, languagePairId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Vocabulary.fromFirestore).toList());
  }

  Future<void> addVocabulary(String uid, Vocabulary vocab) async {
    await _vocabularies(uid, vocab.languagePairId).add(vocab.toFirestore());
  }

  Future<void> moveToStack(
      String uid, String languagePairId, String vocabId, VocabularyStack stack) async {
    await _vocabularies(uid, languagePairId)
        .doc(vocabId)
        .update({'stack': stack.firestoreValue});
  }

  Future<void> deleteVocabulary(
      String uid, String languagePairId, String vocabId) async {
    await _vocabularies(uid, languagePairId).doc(vocabId).delete();
  }

  // ── Sprachpaare ───────────────────────────────────────────────────────────

  Stream<List<LanguagePair>> watchLanguagePairs(String uid) {
    return _vocabLists(uid)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(LanguagePair.fromFirestore).toList());
  }

  Future<String> addLanguagePair(String uid, LanguagePair pair) async {
    final ref = await _vocabLists(uid).add(pair.toFirestore());
    return ref.id;
  }

  Future<void> deleteLanguagePair(String uid, String pairId) async {
    // Zuerst alle Vokabeln löschen (Subcollection wird nicht automatisch gelöscht)
    final vocabs = await _vocabularies(uid, pairId).get();
    final batch = _db.batch();
    for (final doc in vocabs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_vocabLists(uid).doc(pairId));
    await batch.commit();
  }

  Future<void> resetLanguagePair(String uid, String pairId) async {
    final vocabs = await _vocabularies(uid, pairId).get();
    final batch = _db.batch();
    for (final doc in vocabs.docs) {
      batch.update(doc.reference, {'stack': 'training'});
    }
    await batch.commit();
  }

  // ── Userprofil ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<UserProfile?> getUserProfileModel(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserProfile.fromFirestore(doc);
    }
    return null;
  }

  Future<void> saveUserProfile(String uid, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  // ── Global Catalog ────────────────────────────────────────────────────────

  Future<void> uploadGlobalCatalog(List<Map<String, dynamic>> items) async {
    final batch = _db.batch();
    final collection = _db.collection('global_catalog');

    for (var item in items) {
      final docRef = collection.doc();
      batch.set(docRef, item);
    }

    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> fetchGlobalCatalog(String language) async {
    final snapshot = await _db
        .collection('global_catalog')
        .where('language', isEqualTo: language)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Liefert bis zu [limit] Vorschläge aus dem Katalog anhand eines Suchbegriff-Präfix.
  /// Verwendet client-seitiges Filtern (kein Composite-Index nötig, ~200 Einträge).
  Future<List<Map<String, dynamic>>> searchCatalogSuggestions(
      String language, String query, {bool isReverse = false, int limit = 5}) async {
    if (query.isEmpty) return [];
    final all = await fetchGlobalCatalog(language);
    final field = isReverse ? 'translation' : 'term';
    final q = query.toLowerCase();
    return all
        .where((e) => (e[field] as String? ?? '').toLowerCase().startsWith(q))
        .take(limit)
        .toList();
  }

  /// Sucht einen genauen Katalogeintrag und gibt die Übersetzung zurück.
  Future<String?> findCatalogTranslation(
      String language, String term, {bool isReverse = false}) async {
    final field = isReverse ? 'translation' : 'term';
    final resultField = isReverse ? 'term' : 'translation';
    final snapshot = await _db
        .collection('global_catalog')
        .where('language', isEqualTo: language)
        .where(field, isEqualTo: term)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data()[resultField] as String?;
  }


  // ── Gamification ──────────────────────────────────────────────────────────

  Future<List<UserProfile>> getLeaderboard({int limit = 10}) async {
    final snapshot = await _db
        .collection('users')
        .orderBy('xp', descending: true)
        .limit(limit)
        .get();
    final users = snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)).toList();
    
    // Sekundäres Sortierkriterium bei Punktegleichstand (Alphabetisch nach Name)
    users.sort((a, b) {
      if (b.xp != a.xp) return b.xp.compareTo(a.xp);
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return users;
  }

  Stream<List<BadgeModel>> watchBadges(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('badges')
        .orderBy('unlockedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => BadgeModel.fromFirestore(doc)).toList());
  }

  Future<void> unlockBadge(String uid, BadgeModel badge) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('badges')
        .doc(badge.id) // using fixed ID prevents duplicates
        .set(badge.toFirestore());
  }
}
