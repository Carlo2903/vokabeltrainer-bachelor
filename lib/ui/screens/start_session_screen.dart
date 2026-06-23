import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/language_provider.dart';
import '../theme/app_theme.dart';

// ── Trainings-Modus ──────────────────────────────────────────────────────────

/// Die zwei möglichen Trainings-Modi die der Nutzer wählen kann.
enum _SessionMode {
  /// Klassisches Karteikarten-Training: Karte umdrehen, Richtig/Falsch drücken.
  flashcard,

  /// Sprachbasiertes Training: Fremdsprachenwort sprechen, KI bewertet Antwort.
  voice,
}

// ── Screen ───────────────────────────────────────────────────────────────────

/// Konfigurationsscreen vor dem Start einer Lerneinheit.
///
/// Neu: Der Nutzer wählt hier zwischen dem klassischen [_SessionMode.flashcard]-
/// Modus und dem KI-gestützten [_SessionMode.voice]-Modus.
/// Je nach Auswahl navigiert der Start-Button zu '/session/active' bzw.
/// '/session/voice'.
///
/// Wird als StatefulWidget implementiert, da [_selectedMode] lokaler
/// UI-State ist — die Modus-Auswahl beeinflusst nur die Navigation
/// und muss nicht global (im SessionProvider) gespeichert werden.
class StartSessionScreen extends StatefulWidget {
  const StartSessionScreen({super.key});

  @override
  State<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends State<StartSessionScreen> {
  // Standardmäßig ist der klassische Karteikartenmodus vorausgewählt
  _SessionMode _selectedMode = _SessionMode.flashcard;

  @override
  Widget build(BuildContext context) {
    return Consumer2<VocabularyProvider, SessionProvider>(
      builder: (context, vocabProv, sessionProv, _) {
        final masterCount = vocabProv.training.length + vocabProv.review.length;

        return Scaffold(
          backgroundColor: const Color(0xFF0A0C10),
          body: SafeArea(
            child: Column(children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Text('Konfiguration',
                        style: GoogleFonts.lexend(
                            color: AppColors.textSecondary, fontSize: 16)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.help_outline,
                          color: AppColors.textSecondary),
                      onPressed: () => _showHelpSheet(context),
                    ),
                  ],
                ),
              ),

              // ── Scrollbarer Inhalt ───────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titel
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.lexend(
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          children: [
                            const TextSpan(text: 'Training starten'),
                            TextSpan(
                                text: '.',
                                style: GoogleFonts.lexend(
                                    color: const Color(0xFF13EC5B),
                                    fontSize: 38,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Text(
                          'Passe dein tägliches Wiederholungsprogramm individuell an..',
                          style:
                              GoogleFonts.lexend(color: AppColors.textSecondary)),
                      const SizedBox(height: 28),

                      // Meisterstapel-Card
                      _buildMasterPileCard(masterCount),
                      const SizedBox(height: 28),

                      // ── NEU: Modus-Auswahl ─────────────────────────────
                      Text('Trainings-Modus',
                          style: GoogleFonts.lexend(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      _buildModeSelector(),
                      const SizedBox(height: 28),

                      // Übersetzungsrichtung — nur im Karteikartenmodus relevant
                      // AnimatedSwitcher blendet den Block sanft aus/ein
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: -1,
                            child: child,
                          ),
                        ),
                        child: _selectedMode == _SessionMode.flashcard
                            ? Column(
                                key: const ValueKey('direction'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Übersetzungsrichtung',
                                      style: GoogleFonts.lexend(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 14),
                                  _buildDirectionSelector(context, sessionProv),
                                  const SizedBox(height: 28),
                                ],
                              )
                            : const SizedBox.shrink(key: ValueKey('no-direction')),
                      ),

                      // Sitzungsdauer
                      _buildSessionLengthSlider(context, sessionProv),
                      const SizedBox(height: 24),

                      // Streak-Banner
                      _buildStreakBanner(),
                    ],
                  ),
                ),
              ),
            ]),
          ),

          // ── Start-Button ────────────────────────────────────────────────
          bottomSheet: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xFF0A0C10)],
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: masterCount == 0
                    ? null
                    : () {
                        // Session im SessionProvider initialisieren
                        sessionProv.startSession(vocabProv.all);

                        // Route je nach gewähltem Modus
                        final route = _selectedMode == _SessionMode.voice
                            ? '/session/voice'
                            : '/session/active';
                        Navigator.of(context).pushNamed(route);
                      },
                icon: Icon(
                  _selectedMode == _SessionMode.voice
                      ? Icons.mic_rounded
                      : Icons.arrow_forward,
                ),
                label: Text(
                  _selectedMode == _SessionMode.voice
                      ? 'Sprachtraining starten'
                      : 'Session starten',
                  style: GoogleFonts.lexend(
                      fontWeight: FontWeight.w800, fontSize: 17),
                ),
                style: ElevatedButton.styleFrom(
                  // Sprachmodus → Indigo-Akzent, Kartenmodus → Grün
                  backgroundColor: _selectedMode == _SessionMode.voice
                      ? AppColors.primary
                      : const Color(0xFF13EC5B),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.surfaceLight,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  shadowColor: _selectedMode == _SessionMode.voice
                      ? AppColors.primary
                      : const Color(0xFF13EC5B),
                  elevation: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Modus-Selektor ─────────────────────────────────────────────────────────
  //
  // Zwei nebeneinander stehende, selektierbare Cards — identisches Muster wie
  // _buildDirectionSelector. Konsistente Designsprache im gesamten Screen.

  Widget _buildModeSelector() {
    final modes = [
      (
        mode: _SessionMode.flashcard,
        icon: Icons.style_rounded,         // Karten-Icon
        label: 'Karteikarten',
        sublabel: 'Klassisch',
        color: const Color(0xFF00F2FF),    // Cyan — bereits im Direction-Selector
        description: 'Karte umdrehen und\nselbst bewerten',
      ),
      (
        mode: _SessionMode.voice,
        icon: Icons.mic_rounded,           // Mikrofon-Icon
        label: 'Sprachmodus',
        sublabel: 'KI-gestützt',
        color: AppColors.primary,          // Indigo — Primary-Farbe der App
        description: 'Antwort einsprechen,\nKI bewertet automatisch',
      ),
    ];

    return Row(
      children: modes.map((opt) {
        final isSelected = _selectedMode == opt.mode;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedMode = opt.mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? opt.color.withValues(alpha: 0.07)
                      : const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? opt.color
                        : const Color(0xFF30363D).withValues(alpha: 0.5),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: opt.color.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 0,
                          )
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon-Badge
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: opt.color.withValues(
                            alpha: isSelected ? 0.18 : 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: opt.color.withValues(
                              alpha: isSelected ? 0.4 : 0.15),
                        ),
                      ),
                      child: Icon(
                        opt.icon,
                        color: isSelected ? opt.color : AppColors.textMuted,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Modus-Name
                    Text(
                      opt.label,
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Sublabel (z.B. "KI-gestützt")
                    Text(
                      opt.sublabel,
                      style: GoogleFonts.lexend(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isSelected ? opt.color : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Kurzbeschreibung
                    Text(
                      opt.description,
                      style: GoogleFonts.lexend(
                        fontSize: 11,
                        color: isSelected
                            ? AppColors.textSecondary
                            : AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),

                    // Selektiert-Indikator unten rechts
                    if (isSelected) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: opt.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '✓ AKTIV',
                            style: GoogleFonts.lexend(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: opt.color,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Help Bottom Sheet ────────────────────────────────────────────────
  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161B22),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF30363D),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.help_outline_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Konfigurationshilfe',
                            style: GoogleFonts.lexend(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'So funktionieren deine Einstellungen',
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                height: 1,
                color: const Color(0xFF30363D).withValues(alpha: 0.5),
              ),
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    _helpItem(
                      icon: Icons.inventory_2_outlined,
                      iconColor: const Color(0xFF13EC5B),
                      title: 'Meisterstapel',
                      description:
                          'Zeigt die Gesamtzahl deiner Vokabeln, die sich im aktiven Training oder in der Wiederholung befinden. Nur diese Wörter werden in der Session abgefragt.',
                    ),
                    _helpDivider(),
                    _helpItem(
                      icon: Icons.style_rounded,
                      iconColor: const Color(0xFF00F2FF),
                      title: 'Karteikarten-Modus',
                      description:
                          'Das klassische Karteikarten-Training: Ein Wort wird angezeigt, du denkst an die Übersetzung und deckst dann die Lösung auf. Du bewertest dich selbst mit Richtig oder Falsch.',
                    ),
                    _helpDivider(),
                    _helpItem(
                      icon: Icons.mic_rounded,
                      iconColor: AppColors.primary,
                      title: 'Sprachmodus',
                      description:
                          'KI-gestütztes Sprachtraining: Die App zeigt dir ein Fremdsprachenwort. Du sprichst deine Übersetzung auf Deutsch ein – Whisper erkennt deine Sprache und das KI-Modell bewertet deine Antwort automatisch.',
                    ),
                    _helpDivider(),
                    _helpItem(
                      icon: Icons.swap_horiz_rounded,
                      iconColor: const Color(0xFF00F2FF),
                      title: 'Übersetzungsrichtung',
                      description:
                          'Lege fest, in welche Richtung du übersetzen möchtest (nur im Karteikarten-Modus):\n\n'
                          '• Standard – von deiner Ausgangssprache in die Zielsprache.\n'
                          '• Umkehren – von der Zielsprache zurück in die Ausgangssprache.\n'
                          '• Gemischt – beide Richtungen werden zufällig kombiniert.',
                    ),
                    _helpDivider(),
                    _helpItem(
                      icon: Icons.tune_rounded,
                      iconColor: AppColors.accent,
                      title: 'Sitzungsdauer',
                      description:
                          'Bestimme, wie viele Vokabeln du pro Sitzung abfragen möchtest (5–50 Wörter). Kürzere Sessions eignen sich für einen schnellen täglichen Check-in, längere für intensives Üben.',
                    ),
                    _helpDivider(),
                    _helpItem(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: Colors.orange,
                      title: 'Tägliche Serie',
                      description:
                          'Hier siehst du deinen aktuellen Lern-Streak – also wie viele Tage du in Folge mindestens eine Session abgeschlossen hast. Halte deinen Streak am Laufen, um kontinuierlich Fortschritte zu erzielen!',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: iconColor.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lexend(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpDivider() => Container(
        height: 1,
        color: const Color(0xFF30363D).withValues(alpha: 0.4),
      );

  // ── Section Builders (unverändert) ────────────────────────────────────────

  Widget _buildMasterPileCard(int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF30363D).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MEISTERSTAPEL',
                style: GoogleFonts.lexend(
                    fontSize: 9,
                    color: const Color(0xFF13EC5B),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8)),
            const SizedBox(height: 4),
            Text('$count Wörter',
                style: GoogleFonts.lexend(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
            Text('Bereit zur Überprüfung',
                style: GoogleFonts.lexend(
                    fontSize: 13, color: AppColors.textSecondary)),
          ]),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF13EC5B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF13EC5B).withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.inventory_2, color: Color(0xFF13EC5B)),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionSelector(BuildContext context, SessionProvider prov) {
    final pair = context.watch<LanguageProvider>().selected;
    final src = pair?.sourceFlag ?? '🏳️';
    final tgt = pair?.targetFlag ?? '🏳️';

    final options = [
      (TranslationDirection.standard, '$src→$tgt', 'Standard'),
      (TranslationDirection.reverse, '$tgt→$src', 'Umkehren'),
      (TranslationDirection.mixed, '⇄', 'Gemischt'),
    ];
    return Row(
      children: options.map((opt) {
        final isSelected = prov.direction == opt.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => prov.setDirection(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00F2FF)
                        : const Color(0xFF30363D).withValues(alpha: 0.5),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          const BoxShadow(
                              color: Color(0x3300F2FF),
                              blurRadius: 16,
                              spreadRadius: 2)
                        ]
                      : null,
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(opt.$2,
                          style: GoogleFonts.lexend(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Text(opt.$3,
                          style: GoogleFonts.lexend(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                              color: isSelected
                                  ? const Color(0xFF00F2FF)
                                  : AppColors.textMuted)),
                    ]),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSessionLengthSlider(BuildContext context, SessionProvider prov) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF30363D).withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Sitzungsdauer',
                style: GoogleFonts.lexend(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${prov.sessionLength}',
                    style: GoogleFonts.lexend(
                        fontSize: 38,
                        color: const Color(0xFF00F2FF),
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Text('wörter',
                    style: GoogleFonts.lexend(
                        fontSize: 13, color: AppColors.textMuted)),
              ],
            ),
          ]),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00F2FF),
              inactiveTrackColor: const Color(0xFF30363D),
              thumbColor: const Color(0xFF00F2FF),
              overlayColor: const Color(0x3300F2FF),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            ),
            child: Slider(
              value: prov.sessionLength.toDouble(),
              min: 5,
              max: 50,
              divisions: 9,
              onChanged: (v) => prov.setSessionLength(v.round()),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('SCHNELL',
                style: GoogleFonts.lexend(
                    fontSize: 9,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
            Text('INTENSIV',
                style: GoogleFonts.lexend(
                    fontSize: 9,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
          ]),
        ],
      ),
    );
  }

  Widget _buildStreakBanner() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF30363D).withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TÄGLICHE SERIE',
                  style: GoogleFonts.lexend(
                      fontSize: 9,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.local_fire_department,
                    color: Colors.orange, size: 20),
                const SizedBox(width: 6),
                Text('0 tage',
                    style: GoogleFonts.lexend(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ]),
            ],
          ),
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: 0.8,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                color: const Color(0xFF13EC5B),
                strokeWidth: 4,
              ),
              Text('80%',
                  style: GoogleFonts.lexend(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }
}
