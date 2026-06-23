/// Eine einzelne konjugierte Form (z. B. Person + konjugiertes Verb).
class ConjugationEntry {
  /// Subjekt / Personalpronomen, z. B. "ich", "yo".
  final String subject;

  /// Konjugierte Verbform, z. B. "lerne", "aprendo".
  final String form;

  const ConjugationEntry({required this.subject, required this.form});

  factory ConjugationEntry.fromJson(Map<String, dynamic> json) {
    return ConjugationEntry(
      subject: json['subject'] as String? ?? '',
      form: json['form'] as String? ?? '',
    );
  }

  @override
  String toString() => '$subject: $form';
}

/// Konjugationstabelle für eine Zeitform.
class TenseTable {
  /// Name der Zeitform, z. B. "Präsens", "Pretérito Indefinido".
  final String tense;

  /// Alle Konjugationsformen dieser Zeitform.
  final List<ConjugationEntry> entries;

  /// Optionaler Beispielsatz aus dem Sprachmodell.
  final String? exampleSentence;

  const TenseTable({
    required this.tense,
    required this.entries,
    this.exampleSentence,
  });

  factory TenseTable.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? [];
    return TenseTable(
      tense: json['tense'] as String? ?? '',
      entries: rawEntries
          .map((e) => ConjugationEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      exampleSentence: json['example_sentence'] as String?,
    );
  }
}

/// Vollständiges Ergebnis eines Konjugations-Calls an POST /api/chat (mode=conjugation).
class ConjugationResult {
  /// Das angefragte Verb in seiner Grundform.
  final String verb;

  /// Sprache des Verbs, z. B. "Spanisch".
  final String language;

  /// Liste der Konjugationstabellen je Zeitform.
  final List<TenseTable> tables;

  /// Rohtext-Antwort des Sprachmodells (Fallback falls Parsing fehlschlägt).
  final String rawResponse;

  const ConjugationResult({
    required this.verb,
    required this.language,
    required this.tables,
    required this.rawResponse,
  });

  factory ConjugationResult.fromJson(Map<String, dynamic> json, {
    required String verb,
    required String language,
  }) {
    // Das Backend liefert entweder strukturierte "tables" oder nur "response".
    final rawTables = json['tables'] as List<dynamic>? ?? [];
    return ConjugationResult(
      verb: verb,
      language: language,
      tables: rawTables
          .map((t) => TenseTable.fromJson(t as Map<String, dynamic>))
          .toList(),
      rawResponse: json['response'] as String? ?? '',
    );
  }

  /// True wenn das Backend strukturierte Tabellen geliefert hat.
  bool get hasStructuredData => tables.isNotEmpty;
}
