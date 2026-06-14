import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/vocabulary.dart';
import '../../models/vocabulary_stack.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/language_provider.dart';
import '../theme/app_theme.dart';
import 'ocr_scan_screen.dart';

class AddVocabularyScreen extends StatefulWidget {
  const AddVocabularyScreen({super.key});

  @override
  State<AddVocabularyScreen> createState() => _AddVocabularyScreenState();
}

class _AddVocabularyScreenState extends State<AddVocabularyScreen> {
  final _termController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _translationController = TextEditingController();
  bool _isSaving = false;
  bool _isSwapped = false;

  // Smart Suggest
  List<({String term, String translation})> _suggestions = [];
  bool _isLoadingSuggestions = false;
  bool _noResults = false;
  Timer? _debounce;

  // Auto-fill
  bool _isAutoFilling = false;
  bool _autoFillNotFound = false;

  @override
  void initState() {
    super.initState();
    _termController.addListener(_onTermChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _termController.removeListener(_onTermChanged);
    _termController.dispose();
    _descriptionController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  /// Liest die aktuelle Eingaberichtung und gibt query-Kontext weiter
  void _onTermChanged() {
    _debounce?.cancel();
    final query = _termController.text.trim();
    if (query.length < 2) {
      if (_suggestions.isNotEmpty || _noResults) {
        setState(() { _suggestions = []; _noResults = false; });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String query) async {
    final pair = context.read<LanguageProvider>().selected;
    if (pair == null) return;
    final src = _isSwapped ? pair.targetLanguage : pair.sourceLanguage;
    final tgt = _isSwapped ? pair.sourceLanguage : pair.targetLanguage;

    setState(() { _isLoadingSuggestions = true; _noResults = false; });
    final vocabProv = context.read<VocabularyProvider>();
    final results = await vocabProv.searchSuggestions(src, tgt, query);
    if (mounted) setState(() {
      _suggestions = results;
      _isLoadingSuggestions = false;
      _noResults = results.isEmpty;
    });
  }

  void _applySuggestion(({String term, String translation}) entry) {
    _termController.text = entry.term;
    _translationController.text = entry.translation;
    setState(() => _suggestions = []);
  }

  Future<void> _autoFill() async {
    final term = _termController.text.trim();
    if (term.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bitte zuerst einen Begriff eingeben.', style: GoogleFonts.lexend()),
        backgroundColor: AppColors.surface,
      ));
      return;
    }
    final pair = context.read<LanguageProvider>().selected;
    if (pair == null) return;
    final src = _isSwapped ? pair.targetLanguage : pair.sourceLanguage;
    final tgt = _isSwapped ? pair.sourceLanguage : pair.targetLanguage;

    setState(() => _isAutoFilling = true);
    final translation = await context.read<VocabularyProvider>().autoFillTranslation(src, tgt, term);
    if (!mounted) return;
    setState(() {
      _isAutoFilling = false;
      _autoFillNotFound = translation == null;
    });
    if (translation != null) {
      _translationController.text = translation;
    }
  }

  Future<void> _save() async {
    final term = _termController.text.trim();
    final translation = _translationController.text.trim();
    if (term.isEmpty || translation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Begriff und Übersetzung sind erforderlich',
            style: GoogleFonts.lexend())),
      );
      return;
    }

    final langProv = context.read<LanguageProvider>();
    final vocabProv = context.read<VocabularyProvider>();
    final pair = langProv.selected;
    if (pair == null) return;

    setState(() => _isSaving = true);
    final vocab = Vocabulary(
      id: '',
      term: term,
      description: _descriptionController.text.trim(),
      translation: translation,
      stack: VocabularyStack.training,
      languagePairId: pair.id,
      createdAt: DateTime.now(),
    );
    await vocabProv.addVocabulary(vocab);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pair = context.watch<LanguageProvider>().selected;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C0A),
      body: SafeArea(
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0A0C0A),
              border: Border(bottom: BorderSide(color: Color(0xFF333633))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Zurück',
                      style: GoogleFonts.lexend(color: AppColors.mastered, fontSize: 15)),
                ),
                Text('Vokabeln hinzufügen',
                    style: GoogleFonts.lexend(
                        fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: _isSaving ? null : _save,
                  child: Text('Weiter',
                      style: GoogleFonts.lexend(
                          color: AppColors.mastered, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
              child: Column(children: [
                // Smarter Scan Button
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 24),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final pair = context.read<LanguageProvider>().selected;
                      if (pair != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OcrScanScreen(courseId: pair.id, languagePair: pair),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.document_scanner, color: Colors.black),
                    label: Text('Text aus Bild scannen', style: GoogleFonts.lexend(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mastered,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                // Sprachpaar-Selektor
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF333633)),
                  ),
                  child: Row(children: [
                    Expanded(child: _langButton(
                        flag: _isSwapped ? (pair?.targetFlag ?? '🏳️') : (pair?.sourceFlag ?? '🏳️'),
                        label: _isSwapped ? (pair?.targetLanguage ?? 'Target') : (pair?.sourceLanguage ?? 'Source'))),
                    GestureDetector(
                      onTap: () {
                        final termText = _termController.text;
                        _termController.text = _translationController.text;
                        _translationController.text = termText;
                        setState(() {
                          _isSwapped = !_isSwapped;
                          _suggestions = [];
                        });
                      },
                      child: AnimatedRotation(
                        turns: _isSwapped ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.mastered,
                            boxShadow: [BoxShadow(color: AppColors.mastered.withValues(alpha: 0.25),
                                blurRadius: 12)],
                          ),
                          child: const Icon(Icons.swap_horiz, color: Colors.black, size: 20),
                        ),
                      ),
                    ),
                    Expanded(child: _langButton(
                        flag: _isSwapped ? (pair?.sourceFlag ?? '🏳️') : (pair?.targetFlag ?? '🏳️'),
                        label: _isSwapped ? (pair?.sourceLanguage ?? 'Source') : (pair?.targetLanguage ?? 'Target'))),
                  ]),
                ),
                const SizedBox(height: 28),

                // ── DAS WORT ──────────────────────────────────────────────
                _buildFieldLabel('DAS WORT', trailing: GestureDetector(
                  onTap: () => _fetchSuggestions(_termController.text.trim()),
                  child: Row(children: [
                    _isLoadingSuggestions
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textMuted))
                        : const Icon(Icons.auto_awesome, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text('Smart Suggest',
                        style: GoogleFonts.lexend(fontSize: 10, color: AppColors.textMuted,
                            fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ]),
                )),
                const SizedBox(height: 8),
                _buildTextField(_termController,
                    hint: 'Begriff eingeben', fontSize: 22, fontBold: true),

                // Smart-Suggest Dropdown
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252725),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF333633)),
                    ),
                    child: Column(
                      children: _suggestions.map((entry) {
                        return InkWell(
                          onTap: () => _applySuggestion(entry),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.term,
                                    style: GoogleFonts.lexend(
                                        fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
                                Text(entry.translation,
                                    style: GoogleFonts.lexend(
                                        fontSize: 13, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // Kein Treffer Hinweis
                if (_noResults && !_isLoadingSuggestions)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text('Kein Treffer im Katalog – manuell eingeben',
                          style: GoogleFonts.lexend(
                              fontSize: 11, color: AppColors.textMuted)),
                    ]),
                  ),

                const SizedBox(height: 22),

                // ── DEFINITION ────────────────────────────────────────────
                _buildFieldLabel('DEFINITION / CONTEXT'),
                const SizedBox(height: 8),
                _buildTextArea(_descriptionController, hint: 'Beschreibe die Bedeutung...'),
                const SizedBox(height: 22),

                // ── ÜBERSETZUNG ───────────────────────────────────────────
                _buildFieldLabel('ÜBERSETZUNG', trailing: GestureDetector(
                  onTap: _isAutoFilling ? null : _autoFill,
                  child: Row(children: [
                    _isAutoFilling
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.mastered))
                        : const Icon(Icons.translate, size: 14, color: AppColors.mastered),
                    const SizedBox(width: 4),
                    Text('Auto-fill',
                        style: GoogleFonts.lexend(fontSize: 10,
                            color: _isAutoFilling ? AppColors.textMuted : AppColors.mastered,
                            fontWeight: FontWeight.w700)),
                  ]),
                )),
                const SizedBox(height: 8),
                _buildTextField(_translationController,
                    hint: 'Übersetzung eingeben', fontSize: 18),
                if (_autoFillNotFound)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text('Kein Treffer im Katalog – manuell eingeben',
                          style: GoogleFonts.lexend(fontSize: 11, color: AppColors.textMuted)),
                    ]),
                  ),
                const SizedBox(height: 22),

                // Stapel-Hinweis
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF333633)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF333633),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: const Icon(Icons.folder, color: AppColors.masterBlock),
                    ),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('ZIEL-STAPEL',
                          style: GoogleFonts.lexend(fontSize: 9, color: AppColors.textMuted,
                              fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                      Text('Lernstapel',
                          style: GoogleFonts.lexend(fontSize: 13, color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ]),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
      // Save Button
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        color: const Color(0xFF0A0C0A),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Speichere...' : 'Speichern',
                style: GoogleFonts.lexend(fontWeight: FontWeight.w800,
                    letterSpacing: 1.5, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mastered,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 10,
              shadowColor: AppColors.mastered,
            ),
          ),
        ),
      ),
    );
  }

  Widget _langButton({required String flag, required String label}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(children: [
        Text(flag, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(label.toUpperCase(),
            style: GoogleFonts.lexend(fontSize: 10, color: AppColors.textSecondary,
                fontWeight: FontWeight.w600, letterSpacing: 1.2)),
        const Icon(Icons.expand_more, size: 14, color: AppColors.textMuted),
      ]),
    );
  }

  Widget _buildFieldLabel(String label, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.lexend(fontSize: 10, color: AppColors.mastered,
                fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildTextField(TextEditingController ctrl,
      {required String hint, double fontSize = 16, bool fontBold = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.text,
      autocorrect: true,
      enableSuggestions: true,
      style: GoogleFonts.lexend(
          fontSize: fontSize, color: Colors.white,
          fontWeight: fontBold ? FontWeight.w700 : FontWeight.w400),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF252725),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF333633)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF333633)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.mastered, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
    );
  }

  Widget _buildTextArea(TextEditingController ctrl, {required String hint}) {
    return TextField(
      controller: ctrl,
      maxLines: 3,
      keyboardType: TextInputType.text,
      autocorrect: true,
      enableSuggestions: true,
      style: GoogleFonts.lexend(fontSize: 15, color: Colors.white.withValues(alpha: 0.9), height: 1.5),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF252725),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF333633)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF333633)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.mastered, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    );
  }
}
