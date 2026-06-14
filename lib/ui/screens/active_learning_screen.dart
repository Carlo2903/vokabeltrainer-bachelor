import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/gamification_provider.dart';
import '../theme/app_theme.dart';
import 'success_review_screen.dart';
import 'level_up_screen.dart';

class ActiveLearningScreen extends StatelessWidget {
  const ActiveLearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, session, _) {
        if (session.isFinished) return _buildFinished(context, session);
        if (!session.hasWords) return _buildEmpty(context);

        final progress = session.totalCount == 0
            ? 0.0
            : session.currentIndex / session.totalCount;

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: SafeArea(
            child: Column(children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.close_outlined, color: AppColors.textSecondary),
                    onPressed: () { session.resetSession(); Navigator.of(context).pop(); },
                  ),
                  Expanded(child: Column(children: [
                    Text('SITZUNG • ÜBERBLICK',
                        style: GoogleFonts.lexend(fontSize: 9, color: AppColors.textMuted,
                            fontWeight: FontWeight.w700, letterSpacing: 2)),
                    Text('Vokabeltraining',
                        style: GoogleFonts.lexend(fontSize: 13, color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ])),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
                    onPressed: () {},
                  ),
                ]),
              ),
              // Fortschrittsbalken
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(children: [
                  Text('${session.currentIndex + 1}',
                      style: GoogleFonts.lexend(fontSize: 10, color: const Color(0xFF22C55E),
                          fontWeight: FontWeight.w700)),
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
                  Text('${session.totalCount}',
                      style: GoogleFonts.lexend(fontSize: 10, color: AppColors.textMuted,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              // Karte
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: GestureDetector(
                    onTap: session.flipCard,
                    child: _buildCard(session),
                  ),
                ),
              ),
              // Richtig/Falsch Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Expanded(child: _actionBtn(
                    label: 'Falsch', sublabel: 'Wiederhole',
                    icon: Icons.close, color: const Color(0xFFEF4444),
                    onTap: () {
                      final uid = context.read<AuthProvider>().currentUser?.uid;
                      if (uid != null) session.markWrong(uid);
                    },
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _actionBtn(
                    label: 'Richtig', sublabel: '+10 Punkte',
                    icon: Icons.check, color: const Color(0xFF22C55E),
                    onTap: () async {
                      final uid = context.read<AuthProvider>().currentUser?.uid;
                      if (uid != null) {
                        final gamification = context.read<GamificationProvider>();
                        final oldLevel = gamification.currentLevel;
                        
                        await session.markCorrect(uid);
                        
                        final newLevel = gamification.currentLevel;
                        if (newLevel > oldLevel && context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LevelUpScreen(
                                newLevel: newLevel,
                                earnedXp: 10, // Assuming 10 per word
                                currentXp: gamification.currentXP,
                                nextLevelXp: gamification.xpForNextLevel,
                                masteredWords: session.correctCount,
                              ),
                            ),
                          );
                        }
                      }
                    },
                  )),
                ]),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildCard(SessionProvider session) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey('${session.currentIndex}_${session.isFlipped}'),
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40,
              offset: const Offset(0, 20))],
        ),
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blue)),
                const SizedBox(width: 6),
                Text('Vokabel', style: GoogleFonts.lexend(fontSize: 10,
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              ]),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            session.isFlipped ? session.backText : session.frontText,
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(
                fontSize: 36,
                color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: -1),
          ),
          if (session.isFlipped && (session.currentWord?.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(session.currentWord!.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.lexend(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          ],
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: session.flipCard,
            icon: Icon(session.isFlipped ? Icons.expand_less : Icons.expand_more, size: 16),
            label: Text(session.isFlipped ? 'Antwort ausblenden' : 'Definition anzeigen',
                style: GoogleFonts.lexend(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
          ),
        ]),
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required String sublabel,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: 2)],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.lexend(fontSize: 14, color: color, fontWeight: FontWeight.w700)),
          Text(sublabel, style: GoogleFonts.lexend(fontSize: 9, color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700, letterSpacing: 1)),
        ]),
      ),
    );
  }

  Widget _buildFinished(BuildContext context, SessionProvider session) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 100, height: 100,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF22C55E)),
                child: const Icon(Icons.check, color: Colors.white, size: 56),
              ),
              const SizedBox(height: 32),
              Text('Sitzung abgeschlossen!',
                  style: GoogleFonts.lexend(fontSize: 30, color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text('${session.correctCount} von ${session.totalCount} richtig',
                  style: GoogleFonts.lexend(fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to SuccessReviewScreen
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const SuccessReviewScreen(showBackButton: true)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Erfolge ansehen',
                      style: GoogleFonts.lexend(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    session.resetSession();
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Zurück zum Dashboard',
                      style: GoogleFonts.lexend(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.school_outlined, size: 80, color: AppColors.textMuted),
              const SizedBox(height: 24),
              Text('Keine Wörter im Training',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text('Verschiebe zuerst Wörter in den Trainingsstapel.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 40),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Zurück'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
