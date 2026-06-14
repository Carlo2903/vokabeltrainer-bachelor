import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class DailyGoalScreen extends StatefulWidget {
  const DailyGoalScreen({super.key});

  @override
  State<DailyGoalScreen> createState() => _DailyGoalScreenState();
}

class _DailyGoalScreenState extends State<DailyGoalScreen> {
  int _selectedGoal = 20;
  bool _isLoading = true;
  bool _isSaving = false;

  static const _presets = [5, 10, 15, 20, 30, 50];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goal = await context.read<AuthProvider>().getDailyGoal();
    if (mounted) setState(() { _selectedGoal = goal; _isLoading = false; });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await context.read<AuthProvider>().saveDailyGoal(_selectedGoal);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Text('Ziel auf $_selectedGoal Vokabeln gesetzt.',
              style: GoogleFonts.lexend(color: Colors.white)),
        ]),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        // ── AppBar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: AppColors.background,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(child: Text('Tägliches Ziel',
                textAlign: TextAlign.center,
                style: GoogleFonts.lexend(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w700))),
            const SizedBox(width: 48),
          ]),
        ),
        Expanded(child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Wie viele Vokabeln täglich?',
                      style: GoogleFonts.lexend(fontSize: 26, color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Setze dir ein realistisches Ziel. Regelmäßigkeit schlägt Intensität.',
                      style: GoogleFonts.lexend(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
                  const SizedBox(height: 36),
                  // Aktuelle Auswahl
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Column(
                        key: ValueKey(_selectedGoal),
                        children: [
                          Text('$_selectedGoal',
                              style: GoogleFonts.lexend(
                                  fontSize: 72, color: AppColors.primary,
                                  fontWeight: FontWeight.w700, height: 1.0)),
                          Text('Vokabeln / Tag',
                              style: GoogleFonts.lexend(fontSize: 14, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Preset-Buttons
                  Text('SCHNELLAUSWAHL',
                      style: GoogleFonts.lexend(fontSize: 10, color: AppColors.textMuted,
                          fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.4,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _presets.map((v) {
                      final selected = _selectedGoal == v;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedGoal = v),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? AppColors.primary : AppColors.border,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text('$v', style: GoogleFonts.lexend(
                                fontSize: 18,
                                color: selected ? AppColors.primary : AppColors.textSecondary,
                                fontWeight: FontWeight.w700)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  // Custom Slider
                  Text('ODER EIGENS FESTLEGEN',
                      style: GoogleFonts.lexend(fontSize: 10, color: AppColors.textMuted,
                          fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.surface,
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary.withValues(alpha: 0.15),
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: _selectedGoal.toDouble(),
                      min: 5, max: 50, divisions: 9,
                      onChanged: (v) => setState(() => _selectedGoal = v.round()),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('5', style: GoogleFonts.lexend(fontSize: 11, color: AppColors.textMuted)),
                      Text('50', style: GoogleFonts.lexend(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Tipps-Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Empfehlung', style: GoogleFonts.lexend(
                            fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        _selectedGoal <= 10
                            ? 'Perfekt für einen schnellen täglichen Check-in.'
                            : _selectedGoal <= 20
                                ? 'Ein ausgewogenes Ziel für regelmäßiges Lernen.'
                                : 'Intensives Training – bleib konsequent!',
                        style: GoogleFonts.lexend(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8, shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                          : Text('Ziel speichern',
                              style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
              )),
      ])),
    );
  }
}
