import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../theme/app_theme.dart';

class StackOverviewScreen extends StatelessWidget {
  const StackOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LanguageProvider, VocabularyProvider>(
      builder: (context, langProv, vocabProv, _) {
        final pair = langProv.selected;
        final mastered = vocabProv.mastered.length;
        final total = vocabProv.totalWords;
        final masteryPct = total == 0 ? 0.0 : mastered / total;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.9),
                    border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('LERNPFAD',
                            style: GoogleFonts.lexend(
                                fontSize: 9, color: AppColors.mastered,
                                fontWeight: FontWeight.w700, letterSpacing: 2.2)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Text(
                            pair != null
                                ? '${pair.sourceLanguage}  →  ${pair.targetLanguage}'
                                : 'Kein Sprachpaar',
                            style: GoogleFonts.lexend(
                                fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          if (pair != null) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, color: AppColors.mastered, size: 16),
                          ]
                        ]),
                      ]),
                      IconButton(
                        icon: const Icon(Icons.settings, color: AppColors.textSecondary),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                // Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overall Mastery
                        _buildMasterySection(mastered, total, masteryPct),
                        const SizedBox(height: 28),
                        // Trainingsstapel (groß)
                        _buildTrainingCard(context, vocabProv),
                        const SizedBox(height: 14),
                        // Review + Mastered (2-spaltig)
                        Row(children: [
                          Expanded(child: _buildSmallStackCard(
                            label: 'Wiederholungsstapel',
                            subtitle: 'Erweiterter Stapel',
                            count: vocabProv.review.length,
                            color: AppColors.review,
                            icon: Icons.edit_note,
                          )),
                          const SizedBox(width: 14),
                          Expanded(child: _buildSmallStackCard(
                            label: 'Gemeistert',
                            subtitle: 'Geprüfter Stapel',
                            count: vocabProv.mastered.length,
                            color: AppColors.mastered,
                            icon: Icons.workspace_premium,
                          )),
                        ]),
                        const SizedBox(height: 14),
                        // Master Block / Stammblock
                        _buildMasterBlockCard(vocabProv.all.length),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Start Session Button
          bottomSheet: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/session/start'),
                icon: const Icon(Icons.play_circle_filled),
                label: Text('SITZUNG STARTEN',
                    style: GoogleFonts.lexend(
                        fontWeight: FontWeight.w800, letterSpacing: 2)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mastered,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMasterySection(int mastered, int total, double pct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Gesamtbeherrschung',
                style: GoogleFonts.lexend(
                    fontSize: 11, color: AppColors.textMuted,
                    fontWeight: FontWeight.w600, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.lexend(
                        fontSize: 40, color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.mastered.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('+2% woche',
                      style: GoogleFonts.lexend(
                          fontSize: 11, color: AppColors.mastered, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ]),
          Text('$mastered / $total wörter',
              style: GoogleFonts.lexend(fontSize: 11, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 12),
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: pct.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.mastered,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(color: AppColors.mastered.withValues(alpha: 0.4), blurRadius: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrainingCard(BuildContext context, VocabularyProvider vocabProv) {
    final count = vocabProv.training.length;
    final due = (count * 0.65).round();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.training.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.training.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.training.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.psychology, color: AppColors.training, size: 26),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: AppColors.training, borderRadius: BorderRadius.circular(99)),
              child: Text('$due Heute fällig',
                  style: GoogleFonts.lexend(
                      fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 20),
          Text('Aktuelles Training',
              style: GoogleFonts.lexend(
                  fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700)),
          Text('Trainingsstapel',
              style: GoogleFonts.lexend(
                  fontSize: 10, color: AppColors.textMuted,
                  letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$count',
                    style: GoogleFonts.lexend(
                        fontSize: 40, color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Text('wörter',
                    style: GoogleFonts.lexend(fontSize: 14, color: AppColors.textMuted)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Text('Tagesziel: 65%',
                  style: GoogleFonts.lexend(fontSize: 11, color: AppColors.textSecondary)),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(99),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.65,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.training,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStackCard({
    required String label,
    required String subtitle,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 14),
        Text('$count',
            style: GoogleFonts.lexend(
                fontSize: 30, color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.lexend(
                fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700)),
        Text(subtitle,
            style: GoogleFonts.lexend(
                fontSize: 8, color: AppColors.textMuted,
                letterSpacing: 0.8, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildMasterBlockCard(int total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.masterBlock.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.masterBlock.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.masterBlock.withValues(alpha: 0.1)),
            ),
            child: const Icon(Icons.storage, color: AppColors.masterBlock, size: 24),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Master Block',
                style: GoogleFonts.lexend(
                    fontSize: 15, color: Colors.white, fontWeight: FontWeight.w700)),
            Text('STAMMBLOCK',
                style: GoogleFonts.lexend(
                    fontSize: 9, color: AppColors.textMuted,
                    letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$total',
                style: GoogleFonts.lexend(
                    fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700)),
            Text('INSGESAMT',
                style: GoogleFonts.lexend(
                    fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          ]),
        ],
      ),
    );
  }
}
