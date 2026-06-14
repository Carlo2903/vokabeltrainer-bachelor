import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'change_mail_screen.dart';
import 'change_password_screen.dart';
import 'daily_goal_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  int _dailyGoal = 20;
  bool _loadingGoal = true;

  @override
  void initState() {
    super.initState();
    _loadGoal();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);

    if (value) {
      // Zeit für tägliche Erinnerung (19:00 Uhr)
      await NotificationService().scheduleDailyReminder(hour: 19, minute: 0);
    } else {
      await NotificationService().cancelAll();
    }
  }

  Future<void> _loadGoal() async {
    final goal = await context.read<AuthProvider>().getDailyGoal();
    if (mounted) setState(() { _dailyGoal = goal; _loadingGoal = false; });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Abmelden?', style: GoogleFonts.lexend(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Möchtest du dich wirklich abmelden?',
            style: GoogleFonts.lexend(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Abbrechen', style: GoogleFonts.lexend(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Abmelden',
                style: GoogleFonts.lexend(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final email = auth.currentUser?.email ?? '–';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        // ── AppBar (sticky)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.9),
            border: Border(bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.1))),
          ),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(child: Text('Einstellungen',
                style: GoogleFonts.lexend(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700))),
          ]),
        ),
        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            // ── Konto ──────────────────────────────────────────────────
            _sectionLabel('Konto'),
            _settingsGroup([
              _settingsTile(
                icon: Icons.mail_outline_rounded,
                label: 'E-Mail-Adresse',
                subtitle: email,
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ChangeMailScreen()));
                },
              ),
              _settingsTile(
                icon: Icons.lock_outline_rounded,
                label: 'Passwort ändern',
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                },
              ),
            ]),

            const SizedBox(height: 24),

            // ── Lernen ─────────────────────────────────────────────────
            _sectionLabel('Lernen'),
            _settingsGroup([
              _settingsTile(
                icon: Icons.track_changes_rounded,
                label: 'Tägliches Ziel',
                subtitle: _loadingGoal ? 'Lädt...' : '$_dailyGoal Vokabeln / Tag',
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const DailyGoalScreen()));
                  // Ziel nach Rückkehr neu laden
                  _loadGoal();
                },
              ),
              _settingsTileSwitch(
                icon: Icons.notifications_active_rounded,
                label: 'Erinnerungen',
                value: _notificationsEnabled,
                onChanged: _toggleNotifications,
              ),
              _settingsTile(
                icon: Icons.bug_report_rounded,
                label: 'Test-Benachrichtigung senden',
                subtitle: 'Sendet nach 10 Sekunden eine Erinnerung (zum Testen)',
                onTap: () async {
                  await NotificationService().scheduleTestReminder();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Test-Benachrichtigung in 10 Sekunden!')),
                    );
                  }
                },
              ),
            ]),

            const SizedBox(height: 24),

            // ── Support ────────────────────────────────────────────────
            _sectionLabel('Support'),
            _settingsGroup([
              _settingsTile(
                icon: Icons.info_outline_rounded,
                label: 'Über uns',
                onTap: () => _showAboutSheet(),
              ),
            ]),

            const SizedBox(height: 32),

            // ── Abmelden ───────────────────────────────────────────────
            GestureDetector(
              onTap: _logout,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: 10),
                  Text('Abmelden',
                      style: GoogleFonts.lexend(
                          color: AppColors.danger, fontSize: 16, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),

            const SizedBox(height: 24),
            Center(
              child: Text('Vokabeltrainer App v1.0.0',
                  style: GoogleFonts.lexend(fontSize: 10, color: AppColors.textMuted)),
            ),
            const SizedBox(height: 24),
          ],
        )),
      ])),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(label.toUpperCase(),
        style: GoogleFonts.lexend(
            fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
  );

  Widget _settingsGroup(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.07)),
    ),
    child: Column(children: children
        .expand((w) sync* {
          yield w;
          if (w != children.last) {
            yield Divider(height: 1, color: AppColors.primary.withValues(alpha: 0.06));
          }
        })
        .toList()),
  );

  Widget _settingsTile({
    required IconData icon,
    required String label,
    String? subtitle,
    VoidCallback? onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: GoogleFonts.lexend(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Text(subtitle,
                    style: GoogleFonts.lexend(fontSize: 11, color: AppColors.textMuted)),
            ])),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ]),
        ),
      );

  Widget _settingsTileSwitch({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label,
              style: GoogleFonts.lexend(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            inactiveTrackColor: AppColors.surfaceLight,
          ),
        ]),
      );

  void _showAboutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Vokabeltrainer', style: GoogleFonts.lexend(
              fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Version 1.0.0', style: GoogleFonts.lexend(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          Text(
            'Diese App hilft dir, Vokabeln mit einem intelligenten Lernalgorithmus effektiv zu lernen und dauerhaft zu behalten.',
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Schließen', style: GoogleFonts.lexend(color: AppColors.primary)),
          ),
        ]),
      ),
    );
  }
}
