enum VocabularyStack {
  masterBlock,
  training,
  review,
  mastered;

  String get firestoreValue => name;

  static VocabularyStack fromString(String value) {
    return VocabularyStack.values.firstWhere(
      (e) => e.name == value,
      orElse: () => VocabularyStack.masterBlock,
    );
  }

  String get displayName {
    switch (this) {
      case masterBlock:
        return 'Stammblock';
      case training:
        return 'Trainingsstapel';
      case review:
        return 'Erweiterter Stapel';
      case mastered:
        return 'Geprüfter Stapel';
    }
  }

  String get englishName {
    switch (this) {
      case masterBlock:
        return 'Master Block';
      case training:
        return 'Current Training';
      case review:
        return 'Review Pile';
      case mastered:
        return 'Mastered';
    }
  }
}
