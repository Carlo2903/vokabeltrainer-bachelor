import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/language_pair.dart';
import '../../providers/vocabulary_provider.dart';
import '../theme/app_theme.dart';

class AddLanguageDialog extends StatefulWidget {
  final Future<void> Function(LanguagePair pair) onAdd;
  const AddLanguageDialog({super.key, required this.onAdd});

  @override
  State<AddLanguageDialog> createState() => _AddLanguageDialogState();
}

class _AddLanguageDialogState extends State<AddLanguageDialog> {
  final _titleController = TextEditingController();
  final _levelController = TextEditingController(text: 'A1');
  bool _isSaving = false;
  bool _importCatalog = true;

  // Vordefinierte Optionen – Index-basiert, da Flutter Maps nicht per == vergleicht
  static const List<Map<String, String>> _languagePairs = [
    {
      'label': 'Deutsch 🇩🇪 → Englisch 🇬🇧',
      'source': 'Deutsch', 'sFlag': '🇩🇪',
      'target': 'Englisch', 'tFlag': '🇬🇧',
    },
    {
      'label': 'Deutsch 🇩🇪 → Spanisch 🇪🇸',
      'source': 'Deutsch', 'sFlag': '🇩🇪',
      'target': 'Spanisch', 'tFlag': '🇪🇸',
    },
    {
      'label': 'Englisch 🇬🇧 → Deutsch 🇩🇪',
      'source': 'Englisch', 'sFlag': '🇬🇧',
      'target': 'Deutsch', 'tFlag': '🇩🇪',
    },
    {
      'label': 'Spanisch 🇪🇸 → Deutsch 🇩🇪',
      'source': 'Spanisch', 'sFlag': '🇪🇸',
      'target': 'Deutsch', 'tFlag': '🇩🇪',
    },
    {
      'label': 'Englisch 🇬🇧 → Spanisch 🇪🇸',
      'source': 'Englisch', 'sFlag': '🇬🇧',
      'target': 'Spanisch', 'tFlag': '🇪🇸',
    },
    {
      'label': 'Spanisch 🇪🇸 → Englisch 🇬🇧',
      'source': 'Spanisch', 'sFlag': '🇪🇸',
      'target': 'Englisch', 'tFlag': '🇬🇧',
    },
  ];

  int _selectedIndex = 0;

  Map<String, String> get _selectedPair => _languagePairs[_selectedIndex];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final String sourceLanguage = _selectedPair['source']!;
      final String targetLanguage = _selectedPair['target']!;

      final newPair = LanguagePair(
        id: '',
        title: _titleController.text.trim().isEmpty ? 'Neuer Kurs' : _titleController.text.trim(),
        sourceLanguage: sourceLanguage,
        sourceFlag: _selectedPair['sFlag']!,
        targetLanguage: targetLanguage,
        targetFlag: _selectedPair['tFlag']!,
        level: _levelController.text.trim(),
        createdAt: DateTime.now(),
      );

      // LanguagePair speichern (erledigt der aufrufende Kontext, also LanguageProvider)
      await widget.onAdd(newPair);

      // Optional: Katalog importieren, WENN angewählt
      if (_importCatalog) {

      }

      if (mounted) Navigator.of(context).pop(_importCatalog ? _selectedPair : null);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Neue Sprache',
                style: GoogleFonts.lexend(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Wähle ein Sprachpaar aus.',
                style: GoogleFonts.lexend(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            
            _field(_titleController, 'Kurs-Titel', hint: 'z.B. Mein Training'),
            const SizedBox(height: 16),
            
            Text('SPRACHPAAR', style: GoogleFonts.lexend(fontSize: 10, color: AppColors.textMuted,
                fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedIndex,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceLight,
                  icon: const Icon(Icons.expand_more, color: AppColors.textMuted),
                  style: GoogleFonts.lexend(fontSize: 14, color: Colors.white),
                  onChanged: (idx) {
                    if (idx != null) setState(() => _selectedIndex = idx);
                  },
                  items: List.generate(_languagePairs.length, (i) {
                    return DropdownMenuItem<int>(
                      value: i,
                      child: Text(_languagePairs[i]['label']!),
                    );
                  }),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            _field(_levelController, 'Level (optional)', hint: 'A1, B2, N5 ...'),
            const SizedBox(height: 20),

            // Schalter für Katalog-Import
            Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
               decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
               ),
               child: Row(
                  children: [
                     Expanded(
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                              Text('Vokabeln importieren', 
                                 style: GoogleFonts.lexend(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                              Text('200 Wörter zum Startguthaben', 
                                 style: GoogleFonts.lexend(fontSize: 10, color: AppColors.textMuted)),
                           ],
                        ),
                     ),
                     Switch(
                        value: _importCatalog,
                        onChanged: (val) => setState(() => _importCatalog = val),
                        activeColor: AppColors.primary,
                     )
                  ],
               ),
            ),

            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Abbrechen', style: GoogleFonts.lexend()),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_isSaving ? 'Lade...' : 'Erstellen',
                    style: GoogleFonts.lexend(fontWeight: FontWeight.w700)),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {String hint = ''}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.lexend(fontSize: 10, color: AppColors.textMuted,
          fontWeight: FontWeight.w700, letterSpacing: 1)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        style: GoogleFonts.lexend(fontSize: 14, color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.lexend(color: AppColors.textMuted, fontSize: 14),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    ]);
  }
}
