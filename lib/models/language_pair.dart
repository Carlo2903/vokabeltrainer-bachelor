import 'package:cloud_firestore/cloud_firestore.dart';

class LanguagePair {
  final String title;
  final String id;
  final String sourceLanguage;
  final String sourceFlag;
  final String targetLanguage;
  final String targetFlag;
  final String level;
  final DateTime createdAt;


  const LanguagePair({
    required this.id,
    required this.title,
    required this.sourceLanguage,
    required this.sourceFlag,
    required this.targetLanguage,
    required this.targetFlag,
    this.level = '',
    required this.createdAt,
  });

  factory LanguagePair.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // In deinem Screenshot ist 'languages' ein Array
    final languages = data['languages'] as List<dynamic>? ?? [];

    return LanguagePair(
      id: doc.id,
      // Hier fehlte das Argument 'title'!
      title: data['title'] ?? 'Unbenannter Kurs',
      // Wir nehmen die Sprachen jetzt sauber aus dem Array
      sourceLanguage: languages.isNotEmpty ? languages[0].toString() : 'Deutsch',
      targetLanguage: languages.length > 1 ? languages[1].toString() : 'Englisch',
      sourceFlag: data['sourceFlag'] ?? '🇩🇪',
      targetFlag: data['targetFlag'] ?? '🇬🇧',
      level: data['level'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'languages': [sourceLanguage, targetLanguage],
      'sourceFlag': sourceFlag,
      'targetFlag': targetFlag,
      'level': level,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Hilfreich für die Anzeige in der App
  String get displayName => title;
}
