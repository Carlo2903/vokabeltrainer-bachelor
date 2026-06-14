import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  /// Extrahiert den gesamten erkannten Text als einen einzigen String.
  Future<String> extractText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText result = await recognizer.processImage(inputImage);
    await recognizer.close();
    return result.text;
  }

  /// Extrahiert eine Liste von einzelnen Wörtern aus dem Bild.
  /// Iteriert durch Blöcke -> Zeilen -> Elemente (Wörter).
  Future<List<String>> extractWords(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final result = await recognizer.processImage(inputImage);
    await recognizer.close();

    final words = <String>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final text = element.text.trim();
          // Filter out very short or purely numeric "words" if desired, 
          // or just add everything that isn't empty.
          if (text.isNotEmpty && text.length > 1) {
            // Optional: Basic string cleanup (remove trailing punctuation)
            final cleanText = text.replaceAll(RegExp(r'[^\w\säöüÄÖÜß]'), '');
            if (cleanText.isNotEmpty) {
              words.add(cleanText);
            }
          }
        }
      }
    }
    return words;
  }
}
