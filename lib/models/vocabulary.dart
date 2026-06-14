import 'package:cloud_firestore/cloud_firestore.dart';
import 'vocabulary_stack.dart';

class Vocabulary {
  final String id;
  final String term;
  final String description;
  final String translation;
  final VocabularyStack stack;
  final String languagePairId;
  final DateTime createdAt;

  const Vocabulary({
    required this.id,
    required this.term,
    required this.description,
    required this.translation,
    required this.stack,
    required this.languagePairId,
    required this.createdAt,
  });

  factory Vocabulary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Vocabulary(
      id: doc.id,
      term: data['term'] ?? '',
      description: data['description'] ?? '',
      translation: data['translation'] ?? '',
      stack: VocabularyStack.fromString(data['stack'] ?? 'masterBlock'),
      languagePairId: data['languagePairId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'term': term,
      'description': description,
      'translation': translation,
      'stack': stack.firestoreValue,
      'languagePairId': languagePairId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Vocabulary copyWith({
    String? id,
    String? term,
    String? description,
    String? translation,
    VocabularyStack? stack,
    String? languagePairId,
    DateTime? createdAt,
  }) {
    return Vocabulary(
      id: id ?? this.id,
      term: term ?? this.term,
      description: description ?? this.description,
      translation: translation ?? this.translation,
      stack: stack ?? this.stack,
      languagePairId: languagePairId ?? this.languagePairId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
