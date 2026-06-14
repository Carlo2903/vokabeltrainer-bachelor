import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/ocr_service.dart';
import '../../services/translate_service.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../models/language_pair.dart';
import '../../models/vocabulary.dart';
import '../../models/vocabulary_stack.dart';
import '../widgets/ocr_word_chip.dart';
import '../widgets/vocabulary_import_preview.dart';

class OcrScanScreen extends StatefulWidget {
  final String courseId;
  final LanguagePair languagePair;

  const OcrScanScreen({
    Key? key,
    required this.courseId,
    required this.languagePair,
  }) : super(key: key);

  @override
  State<OcrScanScreen> createState() => _OcrScanScreenState();
}

class _OcrScanScreenState extends State<OcrScanScreen> {
  final _ocrService = OcrService();
  final _translateService = TranslateService();
  final _imagePicker = ImagePicker();

  File? _imageFile;
  bool _isProcessingImage = false;
  bool _isTranslating = false;

  List<String> _detectedWords = [];
  final Set<String> _selectedWords = {};
  
  List<Map<String, String>> _previewVocabularies = [];

  // 1: Bild aufnehmen/wählen
  // 2: Wörter auswählen
  // 3: Vorschau / Importieren
  int _currentStep = 1;

  @override
  void initState() {
    super.initState();
    // Direkt Kamera öffnen beim Start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickImage(ImageSource.camera);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _detectedWords = [];
          _selectedWords.clear();
          _previewVocabularies = [];
          _currentStep = 2; // Gehe zu Schritt 2
        });
        _processImage();
      } else {
        // User hat Picker abgebrochen
        if (_imageFile == null) {
          if (mounted) Navigator.of(context).pop();
        }
      }
    } catch (e) {
      _showError('Fehler beim Bild laden: $e');
    }
  }

  Future<void> _processImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isProcessingImage = true;
    });

    try {
      final words = await _ocrService.extractWords(_imageFile!);
      setState(() {
        _detectedWords = words;
        _isProcessingImage = false;
      });
      
      if (words.isEmpty) {
        _showError('Kein Text auf dem Bild erkannt.');
      }
    } catch (e) {
      setState(() => _isProcessingImage = false);
      _showError('Fehler bei der Texterkennung: $e');
    }
  }

  void _toggleWordSelection(String word) {
    setState(() {
      if (_selectedWords.contains(word)) {
        _selectedWords.remove(word);
      } else {
        _selectedWords.add(word);
      }
    });
  }

  Future<void> _translateSelectedWords() async {
    if (_selectedWords.isEmpty) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      final wordsToTranslate = _selectedWords.toList();

      // Die Quellsprache (das was gescannt wird) ist sourceLanguage des Paares.
      // Die Zielsprache (das was wir wollen) ist targetLanguage.
      final sourceCode = _getLanguageCode(widget.languagePair.sourceLanguage);
      final targetCode = _getLanguageCode(widget.languagePair.targetLanguage);

      final translations = await _translateService.translateBatch(
        wordsToTranslate,
        from: sourceCode,
        to: targetCode,
      );

      final preview = <Map<String, String>>[];
      for (int i = 0; i < wordsToTranslate.length; i++) {
        preview.add({
          'term': wordsToTranslate[i],
          'translation': translations[i],
          'description': '',
        });
      }

      if (mounted) {
        setState(() {
          _previewVocabularies = preview;
          _currentStep = 3;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isTranslating = false);
      _showError('Übersetzungsfehler: $e');
    }
  }

  String _getLanguageCode(String fullLanguageName) {
    // Einfaches Mapping, da Translate API 2-Buchstaben ISO braucht
    final map = {
      'deutsch': 'de', 'englisch': 'en', 'spanisch': 'es',
      'französisch': 'fr', 'italienisch': 'it', 'latein': 'la',
    };
    return map[fullLanguageName.toLowerCase()] ?? 'de'; // Fallback
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.red.shade800,
    ));
  }

  Future<void> _importVocabularies(List<Map<String, String>> finalVocabs) async {
    if (finalVocabs.isEmpty) return;

    // Ladeanimation anzeigen...
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final vocabProvider = context.read<VocabularyProvider>();
      final currentUser = context.read<AuthProvider>().currentUser;
      
      if (currentUser == null) throw Exception('Kein Nutzer angemeldet.');

      for (var v in finalVocabs) {
        final vocab = Vocabulary(
          id: '',
          term: v['term'] ?? '',
          description: v['description'] ?? '',
          translation: v['translation'] ?? '',
          stack: VocabularyStack.training,
          languagePairId: widget.courseId,
          createdAt: DateTime.now(),
        );
        await vocabProvider.addVocabulary(vocab);
      }

      if (mounted) {
        Navigator.of(context).pop(); // Ladekreis zu
        Navigator.of(context).pop(true); // Screen zu, true = Erfolg
      }

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showError('Fehler beim Speichern: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Smarter Import', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_currentStep < 3)
            IconButton(
              icon: const Icon(Icons.photo_library),
              tooltip: 'Aus Galerie wählen',
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
        ],
      ),
      body: _buildBody(theme),
      bottomNavigationBar: _currentStep == 2 && _detectedWords.isNotEmpty
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_currentStep == 1) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF13ec5b)));
    }

    if (_currentStep == 3) {
      return VocabularyImportPreview(
        initialVocabularies: _previewVocabularies,
        onImport: _importVocabularies,
        onCancel: () => setState(() => _currentStep = 2),
      );
    }

    // Step 2: Wort Auswahl
    return Column(
      children: [
        if (_imageFile != null)
          Container(
            height: 150,
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: FileImage(_imageFile!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
              ),
            ),
            child: Center(
              child: _isProcessingImage
                  ? const CircularProgressIndicator(color: Color(0xFF13ec5b))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.document_scanner, color: Colors.white, size: 32),
                        const SizedBox(height: 8),
                        Text('${_detectedWords.length} Wörter auf Bild gefunden', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Wörter antippen, die du lernen möchtest:',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedWords.length == _detectedWords.length) {
                      _selectedWords.clear();
                    } else {
                      _selectedWords.addAll(_detectedWords);
                    }
                  });
                }, 
                child: Text(
                  _selectedWords.length == _detectedWords.length ? 'Alle abwählen' : 'Alle auswählen',
                  style: const TextStyle(color: Color(0xFF13ec5b), fontSize: 13),
                )
              ),
            ],
          ),
        ),

        Expanded(
          child: _detectedWords.isEmpty && !_isProcessingImage
              ? const Center(child: Text('Kein Text auf diesem Bild.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    children: _detectedWords.map((word) {
                      return OcrWordChip(
                        label: word,
                        isSelected: _selectedWords.contains(word),
                        onTap: () => _toggleWordSelection(word),
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: ElevatedButton(
          onPressed: _selectedWords.isEmpty || _isTranslating ? null : _translateSelectedWords,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF13ec5b),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            disabledBackgroundColor: Colors.grey.shade800,
          ),
          child: _isTranslating
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)),
                    SizedBox(width: 12),
                    Text('Übersetze (kann beim 1. Mal dauern)...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))
                  ],
                )
              : Text('Übersetze ${_selectedWords.length} Wörter offline', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
