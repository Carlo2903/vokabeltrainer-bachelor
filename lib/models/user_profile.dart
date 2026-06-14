import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  
  // Gamification fields
  final int xp;
  final int level;
  final int currentStreak;
  final DateTime? lastStudyDate;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.xp = 0,
    this.level = 1,
    this.currentStreak = 0,
    this.lastStudyDate,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserProfile(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'User',
      photoUrl: data['photoUrl'],
      xp: data['xp'] ?? 0,
      level: data['level'] ?? 1,
      currentStreak: data['currentStreak'] ?? 0,
      lastStudyDate: (data['lastStudyDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'xp': xp,
      'level': level,
      'currentStreak': currentStreak,
      if (lastStudyDate != null) 'lastStudyDate': Timestamp.fromDate(lastStudyDate!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserProfile copyWith({
    String? email,
    String? displayName,
    String? photoUrl,
    int? xp,
    int? level,
    int? currentStreak,
    DateTime? lastStudyDate,
  }) {
    return UserProfile(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
    );
  }
}
