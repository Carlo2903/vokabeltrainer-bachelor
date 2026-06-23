/// Ergebnis eines Transkriptions-Calls an POST /api/transcribe.
class TranscriptionResult {
  /// Der von Whisper transkribierte Text.
  final String text;

  /// Die von Whisper erkannte Sprache (z. B. "de", "en", "es").
  final String detectedLanguage;

  const TranscriptionResult({
    required this.text,
    required this.detectedLanguage,
  });

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    return TranscriptionResult(
      text: (json['text'] as String? ?? '').trim(),
      detectedLanguage: json['language'] as String? ?? '',
    );
  }

  @override
  String toString() =>
      'TranscriptionResult(text: $text, detectedLanguage: $detectedLanguage)';
}
