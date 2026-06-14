import 'package:cloud_firestore/cloud_firestore.dart';

class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final String colorHex;
  final DateTime? unlockedAt;

  bool get isUnlocked => unlockedAt != null;

  BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.colorHex,
    this.unlockedAt,
  });

  BadgeModel copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    String? colorHex,
    DateTime? unlockedAt,
  }) {
    return BadgeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  static final List<BadgeModel> catalog = [
    BadgeModel(id: 'level_10', name: 'Vokabel-Meister', description: 'Level 10 erreicht!', iconName: 'workspace_premium', colorHex: '13ec5b'),
    BadgeModel(id: 'streak_7', name: '7 Tage Serie', description: '7 Tage am Stück gelernt!', iconName: 'local_fire_department', colorHex: 'fb923c'),
    BadgeModel(id: 'reader', name: 'Eifriger Leser', description: 'Lerne insgesamt 100 neue Vokabeln.', iconName: 'menu_book', colorHex: '60a5fa'),
    BadgeModel(id: 'speed_learner', name: 'Schneller Lerner', description: 'Schließe 5 Trainingseinheiten ab.', iconName: 'bolt', colorHex: 'eab308'),
    BadgeModel(id: 'expert', name: 'Lexikon-Experte', description: 'Meistere mehr als 500 Vokabeln.', iconName: 'psychology', colorHex: 'a855f7'),
    BadgeModel(id: 'social', name: 'Kontaktfreudig', description: 'Lade einen Freund zur App ein.', iconName: 'groups', colorHex: 'f43f5e'),
    BadgeModel(id: 'top_1', name: 'Top 1% Club', description: 'Erreiche die obersten Ränge auf dem Leaderboard.', iconName: 'workspace_premium', colorHex: 'eab308'),
    BadgeModel(id: 'etymology', name: 'Etymologie-König', description: 'Lerne Vokabeln aus 3 verschiedenen Sprachen.', iconName: 'history_edu', colorHex: '14b8a6'),
  ];

  factory BadgeModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return BadgeModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      iconName: data['iconName'] ?? 'military_tech',
      colorHex: data['colorHex'] ?? '13ec5b', // Default to primary color
      unlockedAt: (data['unlockedAt'] as Timestamp?)?.toDate(),

    );
  }

  Map<String, dynamic> toFirestore() {
    final Map<String, dynamic> map = {
      'name': name,
      'description': description,
      'iconName': iconName,
      'colorHex': colorHex,
    };
    if (unlockedAt != null) {
      map['unlockedAt'] = Timestamp.fromDate(unlockedAt!);
    }
    return map;
  }
}
