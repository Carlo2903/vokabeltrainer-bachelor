import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../../providers/auth_provider.dart';
import '../../providers/backend_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/mic_button.dart';
import 'level_up_screen.dart';
import 'success_review_screen.dart';

// ── Phasen des Screens ───────────────────────────────────────────────────────

/// Beschreibt in welcher Phase sich der Voice-Screen gerade befindet.
/// Jede Phase entspricht einem anderen UI-Zustand.
enum _VoicePhase {
  idle,         // Wort wird gezeigt, Nutzer kann Aufnahme starten
  recording,    // Aufnahme läuft aktiv
  transcribing, // Audiodatei wird an Whisper geschickt
  evaluating,   // Transkription wird von Ollama bewertet
  result,       // Ergebnis wird angezeigt (richtig / falsch)
}

// ── Haupt-Screen ─────────────────────────────────────────────────────────────

/// Voice-Abfrage-Screen: Zeigt ein Fremdsprachenwort und lässt den
/// Nutzer die Übersetzung per Sprache eingeben statt per Tastatur.
///
/// Ablauf:
/// 1. Fremdsprachenwort wird angezeigt [_VoicePhase.idle]
/// 2. Nutzer drückt Mikrofon-Button → Aufnahme startet [_VoicePhase.recording]
/// 3. Nutzer drückt nochmal → Aufnahme stoppt, Whisper wird aufgerufen [_VoicePhase.transcribing]
/// 4. Whisper liefert Text → Ollama bewertet [_VoicePhase.evaluating]
/// 5. Ergebnis (richtig/falsch) wird gezeigt [_VoicePhase.result]
class VoiceLearningScreen extends StatefulWidget {
  const VoiceLearningScreen({super.key});

  @override
  State<VoiceLearningScreen> createState() => _VoiceLearningScreenState();
}

class _VoiceLearningScreenState extends State<VoiceLearningScreen> {
  // Das record-Objekt steuert die Mikrofon-Aufnahme
  final AudioRecorder _recorder = AudioRecorder();

  // Aktuelle Phase des Screens
  _VoicePhase _phase = _VoicePhase.idle;

  // Pfad zur aufgenommenen Audiodatei (temporär)
  String? _audioPath;

  // Der von Whisper transkribierte Text der Nutzerantwort
  String? _transcribedText;

  // Ob Ollama die Antwort als korrekt bewertet hat
  bool? _isCorrect;

  // Fehlermeldung falls etwas schiefläuft
  String? _errorMessage;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    // AudioRecorder muss explizit freigegeben werden (Mikrofon-Ressource)
    _recorder.dispose();
    super.dispose();
  }

  // ── Aufnahme-Logik ─────────────────────────────────────────────────────────

  /// Fragt die Mikrofon-Berechtigung an und startet dann die Aufnahme.
  Future<void> _startRecording() async {
    // 1. Berechtigung prüfen — Android und iOS verlangen explizite Zustimmung
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _showPermissionError();
      return;
    }

    // 2. Temporäres Verzeichnis für die Audiodatei holen
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_answer_${DateTime.now().millisecondsSinceEpoch}.m4a';

    // 3. Aufnahme starten — m4a ist auf Android und iOS nativ unterstützt
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc, // AAC-LC ist effizient und kompatibel
        bitRate: 128000,             // 128 kbps — gut genug für Sprache
        sampleRate: 44100,           // Standard-Samplerate
      ),
      path: path,
    );

    setState(() {
      _audioPath = path;
      _phase = _VoicePhase.recording;
      _errorMessage = null;
    });
  }

  /// Stoppt die Aufnahme und leitet den KI-Verarbeitungsprozess ein.
  Future<void> _stopAndProcess() async {
    // Aufnahme beenden — gibt den Dateipfad zurück
    await _recorder.stop();

    if (_audioPath == null) {
      setState(() => _errorMessage = 'Aufnahme fehlgeschlagen.');
      return;
    }

    final audioFile = File(_audioPath!);
    if (!audioFile.existsSync()) {
      setState(() => _errorMessage = 'Audiodatei nicht gefunden.');
      return;
    }

    // Phase 1: Transkription mit Whisper
    await _transcribeAudio(audioFile);
  }

  /// Schickt die Audiodatei an Whisper und holt die Transkription.
  Future<void> _transcribeAudio(File audioFile) async {
    setState(() => _phase = _VoicePhase.transcribing);

    final backend = context.read<BackendProvider>();
    final result = await backend.transcribeAudio(audioFile);

    if (!mounted) return; // Widget könnte in der Zwischenzeit disposed worden sein

    if (result == null) {
      // Fehler aus BackendProvider holen
      setState(() {
        _phase = _VoicePhase.idle;
        _errorMessage = backend.lastError ?? 'Transkription fehlgeschlagen.';
      });
      return;
    }

    _transcribedText = result.text;

    // Phase 2: Bewertung mit Ollama
    await _evaluateAnswer();
  }

  /// Schickt die Transkription und die korrekte Antwort an Ollama zur Bewertung.
  Future<void> _evaluateAnswer() async {
    setState(() => _phase = _VoicePhase.evaluating);

    final session = context.read<SessionProvider>();
    final backend = context.read<BackendProvider>();
    final langProv = context.read<LanguageProvider>();
    final word = session.currentWord;

    if (word == null) return;

    // Abfrage-Richtung: App zeigt term (Fremdsprache), erwartet translation (Deutsch)
    final correctAnswer = word.translation;

    final isCorrect = await backend.evaluateAnswer(
      userAnswer: _transcribedText ?? '',
      correctAnswer: correctAnswer,
      word: word.term,                                    // Verb-Kontext für das LLM
      language: langProv.selected?.targetLanguage ?? '', // Sprache für das LLM
    );

    if (!mounted) return;

    setState(() {
      _isCorrect = isCorrect;
      _phase = _VoicePhase.result;
      if (isCorrect == null) {
        _errorMessage = backend.lastError ?? 'Bewertung fehlgeschlagen.';
      }
    });
  }

  /// Verarbeitet das Bewertungsergebnis und navigiert weiter.
  Future<void> _handleResult(bool correct) async {
    final session = context.read<SessionProvider>();
    final auth = context.read<AuthProvider>();
    final gamification = context.read<GamificationProvider>();
    final uid = auth.currentUser?.uid;

    if (uid == null) return;

    final oldLevel = gamification.currentLevel;

    if (correct) {
      await session.markCorrect(uid);
    } else {
      await session.markWrong(uid);
    }

    if (!mounted) return;

    // Level-Up prüfen — genau wie im bestehenden ActiveLearningScreen
    final newLevel = gamification.currentLevel;
    if (newLevel > oldLevel) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LevelUpScreen(
          newLevel: newLevel,
          earnedXp: 10,
          currentXp: gamification.currentXP,
          nextLevelXp: gamification.xpForNextLevel,
          masteredWords: session.correctCount,
        ),
      ));
    }

    if (!mounted) return;

    // Session fertig? → Erfolgsscreen
    if (session.isFinished) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const SuccessReviewScreen(showBackButton: true),
        ),
      );
      return;
    }

    // Nächste Vokabel → Screen zurücksetzen
    setState(() {
      _phase = _VoicePhase.idle;
      _transcribedText = null;
      _isCorrect = null;
      _audioPath = null;
      _errorMessage = null;
    });
  }

  // ── Fehlerbehandlung ───────────────────────────────────────────────────────

  void _showPermissionError() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Mikrofon-Zugriff verweigert',
          style: GoogleFonts.lexend(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Bitte erlaube den Mikrofon-Zugriff in den App-Einstellungen, '
          'um den Sprachmodus nutzen zu können.',
          style: GoogleFonts.lexend(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Abbrechen', style: GoogleFonts.lexend(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); // Öffnet direkt die App-Einstellungen
            },
            child: Text('Einstellungen öffnen',
                style: GoogleFonts.lexend(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, session, _) {
        // Session-Ende wurde von außen ausgelöst
        if (session.isFinished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const SuccessReviewScreen(showBackButton: true),
                ),
              );
            }
          });
        }

        if (!session.hasWords) return _buildEmpty();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, session),
                _buildProgressBar(session),
                Expanded(child: _buildBody(session)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── UI-Teile ───────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, SessionProvider session) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_outlined, color: AppColors.textSecondary),
            onPressed: () {
              session.resetSession();
              Navigator.of(context).pop();
            },
          ),
          Expanded(
            child: Column(children: [
              Text(
                'SPRACHTRAINING',
                style: GoogleFonts.lexend(
                    fontSize: 9,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2),
              ),
              Text(
                'Sprich die Übersetzung',
                style: GoogleFonts.lexend(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
          // Platzhalter für symmetrisches Layout
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressBar(SessionProvider session) {
    final progress = session.totalCount == 0
        ? 0.0
        : session.currentIndex / session.totalCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Text(
            '${session.currentIndex + 1}',
            style: GoogleFonts.lexend(
                fontSize: 10,
                color: const Color(0xFF22C55E),
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF1E293B),
                color: const Color(0xFF22C55E),
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${session.totalCount}',
            style: GoogleFonts.lexend(
                fontSize: 10,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(SessionProvider session) {
    return switch (_phase) {
      _VoicePhase.idle      => _buildIdleView(session),
      _VoicePhase.recording => _buildRecordingView(session),
      _VoicePhase.transcribing => _buildLoadingView(
          icon: Icons.graphic_eq_rounded,
          title: 'Spracherkennung...',
          subtitle: 'Whisper analysiert deine Antwort',
        ),
      _VoicePhase.evaluating => _buildLoadingView(
          icon: Icons.psychology_rounded,
          title: 'Bewertung...',
          subtitle: 'KI vergleicht deine Antwort',
        ),
      _VoicePhase.result    => _buildResultView(session),
    };
  }

  // ── Phase: Idle ────────────────────────────────────────────────────────────

  Widget _buildIdleView(SessionProvider session) {
    final word = session.currentWord!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Vokabel-Karte
          _buildWordCard(word.term),
          const SizedBox(height: 12),

          // Kontext: Beschreibung falls vorhanden
          if (word.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                word.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.lexend(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.5),
              ),
            ),

          const SizedBox(height: 48),

          // Anweisung
          Text(
            'Drücke das Mikrofon und spreche\ndeine Übersetzung auf Deutsch',
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(
                fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 40),

          // Mikrofon-Button
          MicButton(
            isRecording: false,
            onTap: _startRecording,
          ),

          const SizedBox(height: 24),

          // Fehleranzeige
          if (_errorMessage != null) _buildErrorBanner(_errorMessage!),
        ],
      ),
    );
  }

  // ── Phase: Recording ───────────────────────────────────────────────────────

  Widget _buildRecordingView(SessionProvider session) {
    final word = session.currentWord!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Vokabel-Karte (kleiner während Aufnahme)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildWordCard(word.term, compact: true),
        ),
        const SizedBox(height: 48),

        // Status-Text
        Text(
          'Aufnahme läuft…',
          style: GoogleFonts.lexend(
              fontSize: 16,
              color: const Color(0xFFEF4444),
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Drücke Stop wenn du fertig bist',
          style: GoogleFonts.lexend(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 40),

        // Animierter Mikrofon-Button (zeigt jetzt Stop-Icon)
        MicButton(
          isRecording: true,
          onTap: _stopAndProcess,
        ),
      ],
    );
  }

  // ── Phase: Loading (Transcribing / Evaluating) ─────────────────────────────

  Widget _buildLoadingView({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsierender Icon-Container
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3), width: 2),
              ),
              child: Icon(icon, color: AppColors.primary, size: 44),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: GoogleFonts.lexend(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // ── Phase: Result ──────────────────────────────────────────────────────────

  Widget _buildResultView(SessionProvider session) {
    final word = session.currentWord!;
    final isCorrect = _isCorrect ?? false;
    final hasError = _errorMessage != null && _isCorrect == null;

    final Color resultColor =
        hasError ? AppColors.textMuted :
        isCorrect ? const Color(0xFF22C55E) :
        const Color(0xFFEF4444);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Ergebnis-Icon
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: resultColor.withValues(alpha: 0.15),
              border:
                  Border.all(color: resultColor.withValues(alpha: 0.4), width: 2),
            ),
            child: Icon(
              hasError ? Icons.error_outline :
              isCorrect ? Icons.check_rounded :
              Icons.close_rounded,
              color: resultColor,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),

          // Ergebnis-Text
          Text(
            hasError ? 'Fehler aufgetreten' :
            isCorrect ? 'Richtig! 🎉' : 'Leider falsch',
            style: GoogleFonts.lexend(
                fontSize: 26,
                color: resultColor,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 28),

          // Du hast gesagt …
          if (_transcribedText != null && _transcribedText!.isNotEmpty)
            _buildInfoCard(
              label: 'Du hast gesagt',
              value: _transcribedText!,
              icon: Icons.mic_rounded,
              color: AppColors.primary,
            ),

          const SizedBox(height: 12),

          // Richtige Antwort
          _buildInfoCard(
            label: 'Richtige Antwort',
            value: word.translation,
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF22C55E),
          ),

          const SizedBox(height: 12),

          // Das abgefragte Wort
          _buildInfoCard(
            label: 'Vokabel',
            value: word.term,
            icon: Icons.translate_rounded,
            color: AppColors.review,
          ),

          // Fehlermeldung
          if (hasError) ...[
            const SizedBox(height: 12),
            _buildErrorBanner(_errorMessage!),
          ],

          const SizedBox(height: 32),

          // Aktions-Buttons
          if (!hasError) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleResult(isCorrect),
                icon: Icon(
                    isCorrect ? Icons.arrow_forward : Icons.refresh_rounded),
                label: Text(
                  isCorrect ? 'Weiter' : 'Nächstes Wort',
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: resultColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ] else ...[
            // Bei Fehler: Nochmal versuchen
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() {
                  _phase = _VoicePhase.idle;
                  _errorMessage = null;
                  _transcribedText = null;
                  _isCorrect = null;
                }),
                icon: const Icon(Icons.refresh_rounded),
                label: Text('Nochmal versuchen',
                    style: GoogleFonts.lexend(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Wort überspringen (zählt als falsch)
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => _handleResult(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Überspringen',
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Wiederverwendbare Bausteine ────────────────────────────────────────────

  /// Zeigt das abgefragte Wort als prominente Karte an.
  Widget _buildWordCard(String term, {bool compact = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 24 : 36),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 32,
              offset: const Offset(0, 16)),
        ],
      ),
      child: Column(
        children: [
          // Badge: Fremdsprache
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(99),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.primary)),
              const SizedBox(width: 6),
              Text(
                'Fremdsprachenwort',
                style: GoogleFonts.lexend(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Text(
            term,
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(
                fontSize: compact ? 28 : 38,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: -1),
          ),
        ],
      ),
    );
  }

  /// Info-Karte für Ergebnis-Anzeige (z.B. "Du hast gesagt: …").
  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.lexend(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.lexend(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Rote Fehlermeldungs-Banner.
  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.lexend(
                  fontSize: 13, color: AppColors.danger, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// Leerer Zustand wenn keine Wörter im Training sind.
  Widget _buildEmpty() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic_off_rounded,
                    size: 72, color: AppColors.textMuted),
                const SizedBox(height: 24),
                Text('Keine Wörter im Training',
                    style: GoogleFonts.lexend(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text('Füge zuerst Wörter zum Trainingsstapel hinzu.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexend(
                        color: AppColors.textSecondary, height: 1.5)),
                const SizedBox(height: 40),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Zurück',
                      style: GoogleFonts.lexend(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
