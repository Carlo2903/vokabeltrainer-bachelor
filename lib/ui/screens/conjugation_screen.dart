import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/conjugation_result.dart';
import '../../providers/backend_provider.dart';
import '../../providers/language_provider.dart';
import '../theme/app_theme.dart';

// ── Unterstützte Sprachen ──────────────────────────────────────────────────────

/// Sprachen die das Ollama-Modell für Konjugationen kennt.
const _supportedLanguages = [
  'Spanisch',
  'Französisch',
  'Englisch',
  'Italienisch',
  'Portugiesisch',
];

// ── Screen ────────────────────────────────────────────────────────────────────

/// KI-Konjugationsscreen — ruft [BackendProvider.getConjugation] auf.
///
/// Der Nutzer gibt ein Verb ein, wählt die Sprache per Chip-Selektor
/// und erhält eine vollständige Konjugationstabelle vom lokalen Ollama-Modell.
///
/// Architektur: [StatefulWidget] für lokalen Eingabe-State.
/// Netzwerkarbeit läuft ausschließlich über [BackendProvider].
class ConjugationScreen extends StatefulWidget {
  /// Optionales Verb das direkt vorausgefüllt wird (z.B. aus der Vokabelliste).
  final String? initialVerb;

  /// Optionale Sprache, die vorausgewählt wird.
  final String? initialLanguage;

  const ConjugationScreen({
    super.key,
    this.initialVerb,
    this.initialLanguage,
  });

  @override
  State<ConjugationScreen> createState() => _ConjugationScreenState();
}

class _ConjugationScreenState extends State<ConjugationScreen> {
  late final TextEditingController _verbController;
  late String _selectedLanguage;
  ConjugationResult? _result;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _verbController = TextEditingController(text: widget.initialVerb ?? '');
    _verbController.addListener(() => setState(() {})); // für Clear-Button

    final langProv = context.read<LanguageProvider>();
    _selectedLanguage = _resolveLanguage(
      widget.initialLanguage,
      langProv.selected?.targetLanguage,
    );

    // Direkt laden wenn Verb vorausgefüllt
    if (widget.initialVerb != null && widget.initialVerb!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _verbController.dispose();
    super.dispose();
  }

  /// Mappt Sprachname aus LanguageProvider auf unterstützte Sprachen.
  String _resolveLanguage(String? preferred, String? fromPair) {
    for (final lang in _supportedLanguages) {
      if (preferred != null &&
          lang.toLowerCase().contains(preferred.toLowerCase())) {
        return lang;
      }
      if (fromPair != null &&
          lang.toLowerCase().contains(fromPair.toLowerCase())) {
        return lang;
      }
    }
    return _supportedLanguages.first;
  }

  // ── Aktionen ──────────────────────────────────────────────────────────────

  Future<void> _search() async {
    final verb = _verbController.text.trim();
    if (verb.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _result = null);

    final result = await context
        .read<BackendProvider>()
        .getConjugation(verb, _selectedLanguage);

    if (!mounted) return;
    setState(() => _result = result);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(context),
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textSecondary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Column(children: [
            Text('KI-KONJUGATION',
                style: GoogleFonts.lexend(
                    fontSize: 9,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2)),
            Text('powered by Ollama',
                style: GoogleFonts.lexend(
                    fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Text('llama3.2',
              style: GoogleFonts.lexend(
                  fontSize: 9,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // ── Suchleiste + Sprachauswahl ─────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Texteingabe ────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Row(children: [
            const SizedBox(width: 16),
            const Icon(Icons.translate_rounded,
                color: AppColors.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _verbController,
                style: GoogleFonts.lexend(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Verb eingeben (z.B. hablar, être)',
                  hintStyle: GoogleFonts.lexend(
                      color: AppColors.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                autocorrect: false,
              ),
            ),
            if (_verbController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textMuted, size: 18),
                onPressed: () {
                  _verbController.clear();
                  setState(() => _result = null);
                },
              ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Sprach-Chips ───────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _supportedLanguages.map((lang) {
              final sel = lang == _selectedLanguage;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedLanguage = lang;
                    _result = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: sel
                            ? AppColors.primary
                            : AppColors.border.withValues(alpha: 0.5),
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Text(lang,
                        style: GoogleFonts.lexend(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel
                                ? AppColors.primary
                                : AppColors.textMuted)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // ── Such-Button ────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: Consumer<BackendProvider>(
          builder: (context, backend, child) => ElevatedButton.icon(
              onPressed: backend.isLoading ? null : _search,
              icon: backend.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.psychology_rounded),
              label: Text(
                backend.isLoading ? 'KI generiert Tabelle…' : 'Konjugieren',
                style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Body (State-Switching) ─────────────────────────────────────────────────

  Widget _buildBody() {
    return Consumer<BackendProvider>(
      builder: (_, backend, child) {
        if (backend.isLoading) return _buildLoadingState();
        if (backend.hasError && _result == null) {
          return _buildErrorState(backend.lastError ?? 'Unbekannter Fehler');
        }
        if (_result == null) return _buildEmptyState();
        return _buildResult(_result!);
      },
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.08),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.auto_stories_rounded,
                color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 24),
          Text('Verb eingeben',
              style: GoogleFonts.lexend(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Gib oben ein Verb ein und wähle\ndie Sprache aus.',
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6),
          ),
          const SizedBox(height: 32),
          Text('Beispiele:',
              style: GoogleFonts.lexend(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: ['hablar', 'être', 'to run', 'parlare']
                .map((v) => GestureDetector(
                      onTap: () {
                        _verbController.text = v;
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.5)),
                        ),
                        child: Text(v,
                            style: GoogleFonts.lexend(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500)),
                      ),
                    ))
                .toList(),
          ),
        ]),
      ),
    );
  }

  // ── Loading State ──────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.psychology_rounded,
                color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 28),
          Text('Ollama generiert…',
              style: GoogleFonts.lexend(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Das Sprachmodell erstellt\ndie Konjugationstabelle',
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6),
          ),
          const SizedBox(height: 32),
          const LinearProgressIndicator(
            color: AppColors.primary,
            backgroundColor: Color(0xFF1E293B),
          ),
          const SizedBox(height: 8),
          Text('Das kann 3–10 Sekunden dauern',
              style: GoogleFonts.lexend(
                  fontSize: 11, color: AppColors.textMuted)),
        ]),
      ),
    );
  }

  // ── Error State ────────────────────────────────────────────────────────────

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.danger.withValues(alpha: 0.1),
              border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.wifi_off_rounded,
                color: AppColors.danger, size: 36),
          ),
          const SizedBox(height: 20),
          Text('Verbindung fehlgeschlagen',
              style: GoogleFonts.lexend(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(error,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5)),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('Erneut versuchen',
                style: GoogleFonts.lexend(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Ergebnis-Ansicht ───────────────────────────────────────────────────────

  Widget _buildResult(ConjugationResult result) {
    // Fallback wenn LLM kein strukturiertes JSON geliefert hat
    if (!result.hasStructuredData && result.rawResponse.isNotEmpty) {
      return _buildRawFallback(result);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: [
        _buildVerbHeader(result),
        const SizedBox(height: 20),
        ...result.tables.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildTenseCard(t),
            )),
      ],
    );
  }

  // ── Verb-Header ────────────────────────────────────────────────────────────

  Widget _buildVerbHeader(ConjugationResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('VERB',
              style: GoogleFonts.lexend(
                  fontSize: 9,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(result.verb.isNotEmpty ? result.verb : _verbController.text,
              style: GoogleFonts.lexend(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5)),
        ]),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('SPRACHE',
              style: GoogleFonts.lexend(
                  fontSize: 9,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              result.language.isNotEmpty
                  ? result.language
                  : _selectedLanguage,
              style: GoogleFonts.lexend(
                  fontSize: 14,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Text('${result.tables.length} Zeitformen',
              style: GoogleFonts.lexend(
                  fontSize: 11, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }

  // ── Zeitform-Card ──────────────────────────────────────────────────────────

  /// Einzelne Zeitform-Card mit Zebra-Streifen für die Konjugations-Zeilen.
  ///
  /// Beim Kolloquium: *"Jede Zeitform ist eine eigenständige semantische
  /// Einheit. Cards machen das visuell klar und ermöglichen später eine
  /// Collapse/Expand-Erweiterung pro Zeitform."*
  Widget _buildTenseCard(TenseTable tense) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // Header: Zeitform-Name
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF1E2A3A),
              AppColors.primary.withValues(alpha: 0.08),
            ]),
            border: Border(
                bottom: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.2))),
          ),
          child: Row(children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text(
              tense.tense.toUpperCase(),
              style: GoogleFonts.lexend(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5),
            ),
            const Spacer(),
            Text('${tense.entries.length} Formen',
                style: GoogleFonts.lexend(
                    fontSize: 9,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
          ]),
        ),

        // Konjugations-Zeilen mit Zebra-Streifen
        ...tense.entries.asMap().entries.map((e) {
          final i = e.key;
          final entry = e.value;
          final isAlt = i % 2 == 1;

          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: isAlt
                  ? Colors.white.withValues(alpha: 0.025)
                  : Colors.transparent,
              border: i > 0
                  ? Border(
                      top: BorderSide(
                          color:
                              Colors.white.withValues(alpha: 0.04)))
                  : null,
            ),
            child: Row(children: [
              // Pronomen / Subjekt — gedimmt, feste Breite
              SizedBox(
                width: 110,
                child: Text(
                  entry.subject,
                  style: GoogleFonts.lexend(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
              ),
              // Konjugierte Form — weiß, fett
              Expanded(
                child: Text(
                  entry.form,
                  style: GoogleFonts.lexend(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ]),
          );
        }),

        // Optional: Beispielsatz
        if (tense.exampleSentence != null &&
            tense.exampleSentence!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              border: Border(
                  top: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.15))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded,
                    color: AppColors.primary.withValues(alpha: 0.5),
                    size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tense.exampleSentence!,
                    style: GoogleFonts.lexend(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
      ]),
    );
  }

  // ── Roh-Fallback ───────────────────────────────────────────────────────────

  /// Anzeige wenn das LLM Freitext statt JSON geliefert hat.
  ///
  /// Beim Kolloquium: *"Robustheit war wichtig — auch wenn das Sprachmodell
  /// kein valides JSON generiert, stürzt die App nicht ab sondern zeigt
  /// die Rohausgabe lesbar an."*
  Widget _buildRawFallback(ConjugationResult result) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: [
        _buildVerbHeader(result),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAB308).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFFEAB308).withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFFEAB308), size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Das Modell hat die Tabelle als Freitext ausgegeben. '
                  'Strukturierte Darstellung nicht möglich.',
                  style: GoogleFonts.lexend(
                      fontSize: 12,
                      color: const Color(0xFFEAB308),
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.border.withValues(alpha: 0.4)),
          ),
          child: SelectableText(
            result.rawResponse,
            style: GoogleFonts.sourceCodePro(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.7),
          ),
        ),
      ],
    );
  }
}
