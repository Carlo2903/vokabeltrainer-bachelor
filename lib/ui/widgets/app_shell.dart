import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/stack_overview_screen.dart';
import '../screens/add_vocabulary_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/success_review_screen.dart';
import '../theme/app_theme.dart';
import '../../providers/language_provider.dart';
import '../../providers/vocabulary_provider.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const _tabs = [
    _TabItem(icon: Icons.grid_view_rounded, label: 'Lernen'),
    _TabItem(icon: Icons.emoji_events_rounded, label: 'Ligen'),
    _TabItem(icon: Icons.military_tech_rounded, label: 'Erfolge'),
    _TabItem(icon: Icons.account_circle_rounded, label: 'Profil'),
  ];

  final _screens = const [
    DashboardScreen(),
    LeaderboardScreen(),
    SuccessReviewScreen(),
    ProfileScreen(),
  ];

  void navigateToProfile() {
    setState(() => _currentIndex = 3);
  }

  @override
  Widget build(BuildContext context) {
    // uid-basierte Subscriptions aktuell halten
    final langProv = context.watch<LanguageProvider>();
    final vocabProv = context.read<VocabularyProvider>();
    if (langProv.selected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        vocabProv.subscribeToLanguagePair(langProv.selected!.id);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens.map((s) {
          // DashboardScreen erhält Callback um zum Profil-Tab zu navigieren
          if (s is DashboardScreen) {
            return DashboardScreen(onProfileTap: navigateToProfile);
          }
          return s;
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddVocabularyScreen()),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20)],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) => _buildNavItem(i)),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final tab = _tabs[index];
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(tab.icon,
              size: 24,
              color: isSelected ? AppColors.primary : AppColors.textMuted),
          const SizedBox(height: 4),
          Text(tab.label,
              style: GoogleFonts.lexend(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isSelected ? AppColors.primary : AppColors.textMuted)),
        ]),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}

// Interner Platzhalter (Dictionary)
class _PlaceholderTab extends StatelessWidget {
  final String title;
  final IconData icon;
  const _PlaceholderTab({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 72, color: AppColors.textMuted),
            const SizedBox(height: 24),
            Text(title,
                style: GoogleFonts.lexend(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('Kommt bald.',
                style: GoogleFonts.lexend(
                    fontSize: 14, color: AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}
