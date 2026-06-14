import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslateService {
  final _modelManager = OnDeviceTranslatorModelManager();

  /// Lädt das Sprachmodell für die angeforderte Sprache herunter, falls es noch nicht lokal installiert ist.
  Future<void> _ensureModelDownloaded(String langCode) async {
    final bcp47Code = _getBcp47Code(langCode);
    final isDownloaded = await _modelManager.isModelDownloaded(bcp47Code.bcpCode);
    
    if (!isDownloaded) {
      await _modelManager.downloadModel(bcp47Code.bcpCode);
    }
  }

  /// Übersetzt einen einzelnen Text.
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    // Falls "from" leer ist (Auto-Detect), nutzen wir einfach Englisch als Fallback, 
    // da On-Device ML Kit reine Auto-Detect ohne explizites BCP47 Source Model nicht gut kann.
    final sourceCode = from.isEmpty ? 'en' : from;
    final targetCode = to;

    await _ensureModelDownloaded(sourceCode);
    await _ensureModelDownloaded(targetCode);

    final translator = OnDeviceTranslator(
      sourceLanguage: _getBcp47Code(sourceCode),
      targetLanguage: _getBcp47Code(targetCode),
    );

    final result = await translator.translateText(text);
    translator.close();
    
    return result;
  }

  /// Übersetzt eine Liste von Wörtern auf einmal.
  /// Da das ML Kit keine eingebaute Batch-Funktion hat, laufen wir iterativ darüber.
  /// Da es komplett offline auf dem Handy läuft, ist das sehr schnell (Millisekunden pro Wort).
  Future<List<String>> translateBatch(
    List<String> words, {
    required String from,
    required String to,
  }) async {
    if (words.isEmpty) return [];

    final sourceCode = from.isEmpty ? 'en' : from;
    final targetCode = to;

    // Modelle sicherstellen (lädt nur herunter, wenn noch nicht passiert)
    await _ensureModelDownloaded(sourceCode);
    await _ensureModelDownloaded(targetCode);

    final translator = OnDeviceTranslator(
      sourceLanguage: _getBcp47Code(sourceCode),
      targetLanguage: _getBcp47Code(targetCode),
    );

    final translations = <String>[];
    for (final word in words) {
      final translated = await translator.translateText(word);
      translations.add(translated);
    }

    translator.close();
    return translations;
  }

  /// Wandelt ISO 639-1 (z.B. 'de', 'en', 'es') in die von Google ML Kit geforderten BCP-47 Enums um.
  TranslateLanguage _getBcp47Code(String code) {
    switch (code.toLowerCase()) {
      case 'de': return TranslateLanguage.german;
      case 'en': return TranslateLanguage.english;
      case 'es': return TranslateLanguage.spanish;
      case 'fr': return TranslateLanguage.french;
      case 'it': return TranslateLanguage.italian;
      // Je nach deinen Kurs-Sprachen musst du diese Liste anpassen.
      // Hinweis: ML Kit Translation (Offline) unterstützt nicht alle Sprachen der Welt, aber ca. 50 wichtige.
      default: return TranslateLanguage.english; 
    }
  }
}
